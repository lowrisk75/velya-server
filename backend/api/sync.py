from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from pydantic import BaseModel
import json

from backend.core.database import get_db
from backend.core.security import get_current_user
from backend.models.alarm import Alarm, User, SyncEvent

router = APIRouter(prefix="/api/sync", tags=["sync"])


class SyncPushItem(BaseModel):
    client_id: str
    event_type: str  # create, update, delete
    data: dict
    timestamp: datetime


class SyncPushRequest(BaseModel):
    device_id: str
    events: List[SyncPushItem]
    last_sync_timestamp: datetime


class SyncPullResponse(BaseModel):
    events: List[dict]
    server_timestamp: datetime


@router.post("/push")
async def push_sync(
    sync_request: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Push changes from device to server"""
    conflicts = []

    for event in sync_request.events:
        # Check for conflicts
        result = await db.execute(
            select(Alarm).where(
                and_(
                    Alarm.client_id == event.client_id,
                    Alarm.user_id == current_user.id
                )
            )
        )
        existing = result.scalar_one_or_none()

        # Simple last-write-wins conflict resolution
        if existing and existing.last_modified_at > event.timestamp:
            conflicts.append({
                "client_id": event.client_id,
                "server_timestamp": existing.last_modified_at,
                "client_timestamp": event.timestamp,
                "resolution": "server_wins"
            })
            continue

        # Apply event
        if event.event_type == "create":
            if not existing:
                alarm = Alarm(
                    user_id=current_user.id,
                    client_id=event.client_id,
                    **event.data
                )
                db.add(alarm)
        elif event.event_type == "update":
            if existing:
                for key, value in event.data.items():
                    setattr(existing, key, value)
                existing.last_modified_at = event.timestamp
        elif event.event_type == "delete":
            if existing:
                existing.deleted_at = event.timestamp

        # Log sync event
        sync_event = SyncEvent(
            user_id=current_user.id,
            alarm_client_id=event.client_id,
            event_type=event.event_type,
            data=event.data,
            device_id=sync_request.device_id,
            timestamp=event.timestamp
        )
        db.add(sync_event)

    # Update user last sync
    current_user.last_sync_at = datetime.utcnow()
    await db.commit()

    return {
        "success": True,
        "conflicts": conflicts,
        "server_timestamp": datetime.utcnow()
    }


@router.get("/pull", response_model=SyncPullResponse)
async def pull_sync(
    since: datetime,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Pull changes from server since timestamp"""
    result = await db.execute(
        select(SyncEvent)
        .where(
            and_(
                SyncEvent.user_id == current_user.id,
                SyncEvent.timestamp > since,
                SyncEvent.device_id != current_user.device_id  # Don't send back own events
            )
        )
        .order_by(SyncEvent.timestamp)
    )
    events = result.scalars().all()

    return SyncPullResponse(
        events=[{
            "client_id": e.alarm_client_id,
            "event_type": e.event_type,
            "data": e.data,
            "timestamp": e.timestamp,
            "device_id": e.device_id
        } for e in events],
        server_timestamp=datetime.utcnow()
    )


class ConnectionManager:
    """Manage WebSocket connections for real-time sync"""
    def __init__(self):
        self.active_connections: dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, websocket: WebSocket, user_id: int):
        if user_id in self.active_connections:
            self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def broadcast_to_user(self, user_id: int, message: dict):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_json(message)
                except:
                    pass


manager = ConnectionManager()


@router.websocket("/ws")
async def websocket_sync(
    websocket: WebSocket,
    token: str,
    db: AsyncSession = Depends(get_db)
):
    """WebSocket endpoint for real-time sync"""
    # Authenticate via query param token
    # (In production, implement proper WS auth)
    user_id = 1  # TODO: Extract from token

    await manager.connect(websocket, user_id)
    try:
        while True:
            data = await websocket.receive_json()

            # Broadcast change to other devices
            await manager.broadcast_to_user(user_id, {
                "type": "sync_event",
                "data": data
            })
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
