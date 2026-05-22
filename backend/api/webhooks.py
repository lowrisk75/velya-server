import secrets
from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from pydantic import BaseModel
import redis.asyncio as redis

from backend.core.database import get_db
from backend.core.security import get_current_user
from backend.core.config import get_settings
from backend.models.alarm import Webhook, WebhookLog, User, Alarm

settings = get_settings()
router = APIRouter(prefix="/api/webhooks", tags=["webhooks"])

# Redis for rate limiting
redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)


# Schemas
class WebhookCreate(BaseModel):
    name: str
    alarm_id: Optional[int] = None


class WebhookResponse(BaseModel):
    id: int
    name: str
    webhook_id: str
    verification_code: str
    alarm_id: Optional[int]
    is_enabled: bool
    rate_limit: int
    total_triggers: int
    last_trigger_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class WebhookAction(BaseModel):
    action: str  # enable, disable, setTime, adjustTime
    hour: Optional[int] = None  # For setTime
    minute: Optional[int] = None  # For setTime
    offsetMinutes: Optional[int] = None  # For adjustTime


class WebhookActionResponse(BaseModel):
    success: bool
    alarmId: Optional[str] = None
    scheduledTime: Optional[datetime] = None
    message: str


# Helper functions
async def check_rate_limit(webhook_id: str, rate_limit: int) -> bool:
    """Check if webhook is rate limited"""
    key = f"webhook:ratelimit:{webhook_id}"
    count = await redis_client.incr(key)

    if count == 1:
        await redis_client.expire(key, 60)  # 1 minute window

    return count <= rate_limit


async def log_webhook_trigger(
    db: AsyncSession,
    webhook: Webhook,
    action: str,
    payload: dict,
    source_ip: str,
    success: bool,
    error_message: Optional[str] = None
):
    """Log webhook trigger"""
    log = WebhookLog(
        webhook_id=webhook.id,
        action=action,
        payload=payload,
        source_ip=source_ip,
        success=success,
        error_message=error_message
    )
    db.add(log)

    webhook.total_triggers += 1
    webhook.last_trigger_at = datetime.utcnow()

    await db.commit()


# Endpoints
@router.post("", response_model=WebhookResponse, status_code=status.HTTP_201_CREATED)
async def create_webhook(
    webhook_create: WebhookCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new webhook"""
    # Generate secure IDs
    webhook_id = secrets.token_urlsafe(16)
    verification_code = secrets.token_urlsafe(32)

    # Verify alarm exists if specified
    if webhook_create.alarm_id:
        result = await db.execute(
            select(Alarm).where(
                and_(
                    Alarm.id == webhook_create.alarm_id,
                    Alarm.user_id == current_user.id
                )
            )
        )
        if not result.scalar_one_or_none():
            raise HTTPException(status_code=404, detail="Alarm not found")

    webhook = Webhook(
        user_id=current_user.id,
        name=webhook_create.name,
        webhook_id=webhook_id,
        verification_code=verification_code,
        alarm_id=webhook_create.alarm_id
    )

    db.add(webhook)
    await db.commit()
    await db.refresh(webhook)

    return webhook


@router.get("", response_model=List[WebhookResponse])
async def list_webhooks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all webhooks for current user"""
    result = await db.execute(
        select(Webhook)
        .where(Webhook.user_id == current_user.id)
        .order_by(Webhook.created_at.desc())
    )
    webhooks = result.scalars().all()

    return webhooks


@router.delete("/{webhook_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_webhook(
    webhook_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a webhook"""
    result = await db.execute(
        select(Webhook).where(
            and_(Webhook.id == webhook_id, Webhook.user_id == current_user.id)
        )
    )
    webhook = result.scalar_one_or_none()

    if not webhook:
        raise HTTPException(status_code=404, detail="Webhook not found")

    await db.delete(webhook)
    await db.commit()


@router.post("/trigger/{webhook_id}", response_model=WebhookActionResponse)
async def trigger_webhook(
    webhook_id: str,  # Public webhook ID (not DB ID)
    action: WebhookAction,
    request: Request,
    x_verification_code: str = Header(...),
    db: AsyncSession = Depends(get_db)
):
    """Public webhook endpoint (no auth required, uses verification code)"""
    # Find webhook
    result = await db.execute(
        select(Webhook).where(Webhook.webhook_id == webhook_id)
    )
    webhook = result.scalar_one_or_none()

    if not webhook:
        raise HTTPException(status_code=404, detail="Webhook not found")

    # Verify code
    if webhook.verification_code != x_verification_code:
        await log_webhook_trigger(
            db, webhook, action.action, action.model_dump(),
            request.client.host, False, "Invalid verification code"
        )
        raise HTTPException(status_code=401, detail="Invalid verification code")

    # Check enabled
    if not webhook.is_enabled:
        await log_webhook_trigger(
            db, webhook, action.action, action.model_dump(),
            request.client.host, False, "Webhook disabled"
        )
        raise HTTPException(status_code=403, detail="Webhook is disabled")

    # Rate limit
    if not await check_rate_limit(webhook_id, webhook.rate_limit):
        await log_webhook_trigger(
            db, webhook, action.action, action.model_dump(),
            request.client.host, False, "Rate limit exceeded"
        )
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    # Get target alarm(s)
    if webhook.alarm_id:
        result = await db.execute(
            select(Alarm).where(Alarm.id == webhook.alarm_id)
        )
        alarms = [result.scalar_one_or_none()]
    else:
        # Apply to all user's alarms
        result = await db.execute(
            select(Alarm)
            .where(and_(Alarm.user_id == webhook.user_id, Alarm.deleted_at.is_(None)))
        )
        alarms = result.scalars().all()

    if not alarms or not alarms[0]:
        await log_webhook_trigger(
            db, webhook, action.action, action.model_dump(),
            request.client.host, False, "No target alarms found"
        )
        raise HTTPException(status_code=404, detail="No alarms found")

    # Execute action
    try:
        for alarm in alarms:
            if action.action == "enable":
                alarm.is_enabled = True
            elif action.action == "disable":
                alarm.is_enabled = False
            elif action.action == "setTime":
                if action.hour is None or action.minute is None:
                    raise ValueError("hour and minute required for setTime")
                alarm.time = datetime.strptime(
                    f"{action.hour:02d}:{action.minute:02d}", "%H:%M"
                ).time()
            elif action.action == "adjustTime":
                if action.offsetMinutes is None:
                    raise ValueError("offsetMinutes required for adjustTime")
                # Convert current time + offset
                current_time = datetime.combine(datetime.today(), alarm.time)
                new_time = current_time + timedelta(minutes=action.offsetMinutes)
                alarm.time = new_time.time()
            else:
                raise ValueError(f"Unknown action: {action.action}")

            alarm.last_modified_at = datetime.utcnow()

        await db.commit()

        # Log success
        await log_webhook_trigger(
            db, webhook, action.action, action.model_dump(),
            request.client.host, True
        )

        return WebhookActionResponse(
            success=True,
            alarmId=alarms[0].client_id if len(alarms) == 1 else None,
            scheduledTime=datetime.combine(datetime.today(), alarms[0].time),
            message=f"Action {action.action} applied to {len(alarms)} alarm(s)"
        )

    except Exception as e:
        await log_webhook_trigger(
            db, webhook, action.action, action.model_dump(),
            request.client.host, False, str(e)
        )
        raise HTTPException(status_code=400, detail=str(e))
