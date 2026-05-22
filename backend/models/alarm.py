from datetime import datetime, time
from typing import Optional
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Time, JSON, ForeignKey, Index
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    device_id = Column(String, unique=True, index=True)  # iPhone UUID
    created_at = Column(DateTime, default=datetime.utcnow)
    last_sync_at = Column(DateTime, nullable=True)

    alarms = relationship("Alarm", back_populates="user", cascade="all, delete-orphan")
    webhooks = relationship("Webhook", back_populates="user", cascade="all, delete-orphan")


class Alarm(Base):
    __tablename__ = "alarms"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # iOS-side UUID for sync
    client_id = Column(String, unique=True, index=True, nullable=False)

    # Alarm properties
    time = Column(Time, nullable=False)
    label = Column(String, default="")
    is_enabled = Column(Boolean, default=True)
    sound = Column(String, default="default")
    repeat_days = Column(JSON, default=list)  # [0,1,2,3,4] for Mon-Fri
    snooze_interval = Column(Integer, default=600)  # seconds

    # Advanced
    vibration = Column(Boolean, default=True)
    volume_override = Column(Integer, nullable=True)  # 0-100
    rules = Column(JSON, default=list)  # Smart rules
    wake_up_actions = Column(JSON, default=list)  # Actions

    # Sleep hours mode
    uses_sleep_hours_mode = Column(Boolean, default=False)
    sleep_hours_target = Column(Integer, nullable=True)  # minutes
    smart_wake_window = Column(Integer, default=30)
    earliest_wake_time = Column(Time, nullable=True)

    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_modified_at = Column(DateTime, default=datetime.utcnow)  # From iOS
    deleted_at = Column(DateTime, nullable=True)  # Soft delete for sync

    # Relationships
    user = relationship("User", back_populates="alarms")

    # Indexes
    __table_args__ = (
        Index("idx_user_enabled", "user_id", "is_enabled"),
        Index("idx_client_id", "client_id"),
    )


class Webhook(Base):
    __tablename__ = "webhooks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Target alarm (optional - can target all)
    alarm_id = Column(Integer, ForeignKey("alarms.id"), nullable=True)

    # Webhook config
    name = Column(String, nullable=False)
    webhook_id = Column(String, unique=True, index=True, nullable=False)  # Public ID
    verification_code = Column(String, nullable=False)

    # Settings
    is_enabled = Column(Boolean, default=True)
    rate_limit = Column(Integer, default=10)  # per minute

    # Stats
    total_triggers = Column(Integer, default=0)
    last_trigger_at = Column(DateTime, nullable=True)

    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="webhooks")

    __table_args__ = (
        Index("idx_webhook_id", "webhook_id"),
    )


class SyncEvent(Base):
    """Track sync events for conflict resolution"""
    __tablename__ = "sync_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    alarm_client_id = Column(String, index=True, nullable=False)

    event_type = Column(String, nullable=False)  # create, update, delete
    data = Column(JSON, nullable=False)
    device_id = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    __table_args__ = (
        Index("idx_user_timestamp", "user_id", "timestamp"),
    )


class WebhookLog(Base):
    """Audit log for webhook triggers"""
    __tablename__ = "webhook_logs"

    id = Column(Integer, primary_key=True, index=True)
    webhook_id = Column(Integer, ForeignKey("webhooks.id"), nullable=False, index=True)

    action = Column(String, nullable=False)  # enable, disable, setTime, adjustTime
    payload = Column(JSON, nullable=False)
    source_ip = Column(String, nullable=True)
    success = Column(Boolean, default=True)
    error_message = Column(String, nullable=True)

    triggered_at = Column(DateTime, default=datetime.utcnow, index=True)

    __table_args__ = (
        Index("idx_webhook_triggered", "webhook_id", "triggered_at"),
    )
