from datetime import datetime, timedelta, time
from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from pydantic import BaseModel

from backend.core.database import get_db
from backend.core.security import get_current_user
from backend.models.alarm import Alarm, User, WebhookLog

router = APIRouter(prefix="/api/stats", tags=["stats"])


class TimelineItem(BaseModel):
    alarm_id: int
    client_id: str
    label: str
    time: time
    is_enabled: bool
    repeat_days: List[int]
    day: str  # ISO date
    scheduled_time: datetime


class TimelineResponse(BaseModel):
    items: List[TimelineItem]
    start_date: datetime
    end_date: datetime


class AlarmStatsResponse(BaseModel):
    total_alarms: int
    enabled_alarms: int
    disabled_alarms: int
    recurring_alarms: int
    one_time_alarms: int
    avg_wake_time: str  # HH:MM format
    most_common_time: str


class WebhookStatsResponse(BaseModel):
    total_webhooks: int
    enabled_webhooks: int
    total_triggers_last_30d: int
    most_active_webhook: dict


@router.get("/timeline", response_model=TimelineResponse)
async def get_timeline(
    days: int = 7,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get timeline of scheduled alarms for next N days"""
    result = await db.execute(
        select(Alarm)
        .where(
            and_(
                Alarm.user_id == current_user.id,
                Alarm.deleted_at.is_(None),
                Alarm.is_enabled == True
            )
        )
        .order_by(Alarm.time)
    )
    alarms = result.scalars().all()

    # Generate timeline items
    items = []
    start_date = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    end_date = start_date + timedelta(days=days)

    for alarm in alarms:
        # For each day in range
        current_day = start_date
        while current_day < end_date:
            day_of_week = current_day.weekday()  # 0=Monday, 6=Sunday

            # Check if alarm fires this day
            fires_today = False
            if alarm.repeat_days:
                # Recurring alarm
                fires_today = day_of_week in alarm.repeat_days
            else:
                # One-time alarm (fires first occurrence only)
                fires_today = current_day == start_date

            if fires_today:
                scheduled_time = datetime.combine(current_day.date(), alarm.time)
                items.append(TimelineItem(
                    alarm_id=alarm.id,
                    client_id=alarm.client_id,
                    label=alarm.label or "Alarm",
                    time=alarm.time,
                    is_enabled=alarm.is_enabled,
                    repeat_days=alarm.repeat_days or [],
                    day=current_day.date().isoformat(),
                    scheduled_time=scheduled_time
                ))

            current_day += timedelta(days=1)

    # Sort by scheduled time
    items.sort(key=lambda x: x.scheduled_time)

    return TimelineResponse(
        items=items,
        start_date=start_date,
        end_date=end_date
    )


@router.get("/alarms", response_model=AlarmStatsResponse)
async def get_alarm_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get aggregate alarm statistics"""
    result = await db.execute(
        select(Alarm)
        .where(
            and_(
                Alarm.user_id == current_user.id,
                Alarm.deleted_at.is_(None)
            )
        )
    )
    alarms = result.scalars().all()

    total = len(alarms)
    enabled = sum(1 for a in alarms if a.is_enabled)
    disabled = total - enabled
    recurring = sum(1 for a in alarms if a.repeat_days)
    one_time = total - recurring

    # Average wake time
    if alarms:
        total_minutes = sum(
            a.time.hour * 60 + a.time.minute for a in alarms
        )
        avg_minutes = total_minutes // len(alarms)
        avg_wake_time = f"{avg_minutes // 60:02d}:{avg_minutes % 60:02d}"

        # Most common time (mode)
        time_counts = {}
        for a in alarms:
            time_str = a.time.strftime("%H:%M")
            time_counts[time_str] = time_counts.get(time_str, 0) + 1
        most_common_time = max(time_counts, key=time_counts.get)
    else:
        avg_wake_time = "00:00"
        most_common_time = "00:00"

    return AlarmStatsResponse(
        total_alarms=total,
        enabled_alarms=enabled,
        disabled_alarms=disabled,
        recurring_alarms=recurring,
        one_time_alarms=one_time,
        avg_wake_time=avg_wake_time,
        most_common_time=most_common_time
    )


@router.get("/webhooks", response_model=WebhookStatsResponse)
async def get_webhook_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get webhook statistics"""
    from backend.models.alarm import Webhook

    # Get webhooks
    result = await db.execute(
        select(Webhook).where(Webhook.user_id == current_user.id)
    )
    webhooks = result.scalars().all()

    total_webhooks = len(webhooks)
    enabled_webhooks = sum(1 for w in webhooks if w.is_enabled)

    # Get trigger count last 30 days
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    result = await db.execute(
        select(func.count(WebhookLog.id))
        .join(Webhook)
        .where(
            and_(
                Webhook.user_id == current_user.id,
                WebhookLog.triggered_at >= thirty_days_ago
            )
        )
    )
    total_triggers = result.scalar() or 0

    # Most active webhook
    if webhooks:
        most_active = max(webhooks, key=lambda w: w.total_triggers)
        most_active_data = {
            "id": most_active.id,
            "name": most_active.name,
            "total_triggers": most_active.total_triggers
        }
    else:
        most_active_data = {}

    return WebhookStatsResponse(
        total_webhooks=total_webhooks,
        enabled_webhooks=enabled_webhooks,
        total_triggers_last_30d=total_triggers,
        most_active_webhook=most_active_data
    )
