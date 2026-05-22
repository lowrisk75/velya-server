from datetime import datetime, time
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from pydantic import BaseModel, Field

from backend.core.database import get_db
from backend.core.security import get_current_user
from backend.models.alarm import Alarm, User, SyncEvent

router = APIRouter(prefix="/api/alarms", tags=["alarms"])


# Schemas
class AlarmBase(BaseModel):
    client_id: str
    time: time
    label: str = ""
    is_enabled: bool = True
    sound: str = "default"
    repeat_days: List[int] = Field(default_factory=list)
    snooze_interval: int = 600
    vibration: bool = True
    volume_override: Optional[int] = None
    rules: List[dict] = Field(default_factory=list)
    wake_up_actions: List[dict] = Field(default_factory=list)
    uses_sleep_hours_mode: bool = False
    sleep_hours_target: Optional[int] = None
    smart_wake_window: int = 30
    earliest_wake_time: Optional[time] = None


class AlarmCreate(AlarmBase):
    pass


class AlarmUpdate(BaseModel):
    time: Optional[time] = None
    label: Optional[str] = None
    is_enabled: Optional[bool] = None
    sound: Optional[str] = None
    repeat_days: Optional[List[int]] = None
    snooze_interval: Optional[int] = None
    vibration: Optional[bool] = None
    volume_override: Optional[int] = None
    rules: Optional[List[dict]] = None
    wake_up_actions: Optional[List[dict]] = None
    uses_sleep_hours_mode: Optional[bool] = None
    sleep_hours_target: Optional[int] = None
    smart_wake_window: Optional[int] = None
    earliest_wake_time: Optional[time] = None


class AlarmResponse(AlarmBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime
    last_modified_at: datetime
    deleted_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# Endpoints
@router.post("", response_model=AlarmResponse, status_code=status.HTTP_201_CREATED)
async def create_alarm(
    alarm: AlarmCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new alarm"""
    # Check if client_id already exists for this user
    result = await db.execute(
        select(Alarm).where(
            and_(Alarm.user_id == current_user.id, Alarm.client_id == alarm.client_id)
        )
    )
    existing = result.scalar_one_or_none()

    if existing and existing.deleted_at is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Alarm with this client_id already exists"
        )

    # Create alarm
    db_alarm = Alarm(
        user_id=current_user.id,
        **alarm.model_dump()
    )
    db.add(db_alarm)

    # Log sync event
    sync_event = SyncEvent(
        user_id=current_user.id,
        alarm_client_id=alarm.client_id,
        event_type="create",
        data=alarm.model_dump(mode='json'),
        device_id=current_user.device_id or "server"
    )
    db.add(sync_event)

    await db.commit()
    await db.refresh(db_alarm)

    return db_alarm


@router.get("", response_model=List[AlarmResponse])
async def list_alarms(
    include_deleted: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all alarms for current user"""
    query = select(Alarm).where(Alarm.user_id == current_user.id)

    if not include_deleted:
        query = query.where(Alarm.deleted_at.is_(None))

    query = query.order_by(Alarm.time)

    result = await db.execute(query)
    alarms = result.scalars().all()

    return alarms


@router.get("/{alarm_id}", response_model=AlarmResponse)
async def get_alarm(
    alarm_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get specific alarm"""
    result = await db.execute(
        select(Alarm).where(
            and_(Alarm.id == alarm_id, Alarm.user_id == current_user.id)
        )
    )
    alarm = result.scalar_one_or_none()

    if not alarm:
        raise HTTPException(status_code=404, detail="Alarm not found")

    return alarm


@router.put("/{alarm_id}", response_model=AlarmResponse)
async def update_alarm(
    alarm_id: int,
    alarm_update: AlarmUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update an alarm"""
    result = await db.execute(
        select(Alarm).where(
            and_(Alarm.id == alarm_id, Alarm.user_id == current_user.id)
        )
    )
    db_alarm = result.scalar_one_or_none()

    if not db_alarm:
        raise HTTPException(status_code=404, detail="Alarm not found")

    # Update fields
    update_data = alarm_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_alarm, field, value)

    db_alarm.last_modified_at = datetime.utcnow()

    # Log sync event
    sync_event = SyncEvent(
        user_id=current_user.id,
        alarm_client_id=db_alarm.client_id,
        event_type="update",
        data=alarm_update.model_dump(mode='json'),
        device_id=current_user.device_id or "server"
    )
    db.add(sync_event)

    await db.commit()
    await db.refresh(db_alarm)

    return db_alarm


@router.delete("/{alarm_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_alarm(
    alarm_id: int,
    permanent: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete an alarm (soft delete by default for sync)"""
    result = await db.execute(
        select(Alarm).where(
            and_(Alarm.id == alarm_id, Alarm.user_id == current_user.id)
        )
    )
    db_alarm = result.scalar_one_or_none()

    if not db_alarm:
        raise HTTPException(status_code=404, detail="Alarm not found")

    if permanent:
        await db.delete(db_alarm)
    else:
        db_alarm.deleted_at = datetime.utcnow()

    # Log sync event
    sync_event = SyncEvent(
        user_id=current_user.id,
        alarm_client_id=db_alarm.client_id,
        event_type="delete",
        data={"alarm_id": alarm_id, "permanent": permanent},
        device_id=current_user.device_id or "server"
    )
    db.add(sync_event)

    await db.commit()
