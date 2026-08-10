const { verifyAccessToken, extractBearerFromHandshake } = require('../utils/tokenHelper');
const {
  canJoinShipmentRoom,
  canJoinOrderRoom,
  canJoinSupportRoom,
  assertCaptainForShipmentLocation,
  assertCaptainForOrderLocation,
} = require('../utils/accessControl');

function registerSocketHandlers(io, activeUsers, refreshSocketUser) {
  io.use(async (socket, next) => {
    try {
      const token = extractBearerFromHandshake(socket.handshake);
      if (!token) {
        return next(new Error('Unauthorized: missing token'));
      }
      const decoded = verifyAccessToken(token);
      if (!decoded?.id) {
        return next(new Error('Unauthorized: invalid token'));
      }
      socket.userId = String(decoded.id);
      socket.role = decoded.role || null;
      socket.userName = null;
      socket.userAvatar = null;
      if (!(await refreshSocketUser(socket))) {
        return next(new Error('Unauthorized'));
      }

      if (!activeUsers.has(socket.userId)) activeUsers.set(socket.userId, new Set());
      activeUsers.get(socket.userId).add(socket.id);

      // Automatically join user-specific and role-specific rooms
      socket.join(`user_${socket.userId}`);
      if (socket.role === 'captain') {
        socket.join(`captain_${socket.userId}`);
      }

      if (socket.role === 'admin' || socket.role === 'employee') {
        socket.join('admins');
      }
      next();
    } catch (err) {
      next(new Error('Unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    console.log('🔌 Socket connected:', socket.id, 'user', socket.userId);

    socket.on('auth', async () => {
      console.log(`🔑 Socket ${socket.id} session ready for user ${socket.userId}`);
    });

    socket.on('join_admin_room', () => {
      if (socket.role === 'admin' || socket.role === 'employee') {
        socket.join('admins');
      }
    });

    socket.on('joinRoom', async (roomName) => {
      if (!socket.userId || !roomName) return;
      if (!(await refreshSocketUser(socket))) return;

      const allowed = await canJoinRoom(socket, roomName);
      if (!allowed) {
        console.log(`⛔ Socket ${socket.id} denied room ${roomName}`);
        socket.emit('room_error', { room: roomName, message: 'غير مصرح بالانضمام لهذه الغرفة' });
        return;
      }

      await refreshSocketUser(socket);
      socket.join(roomName);
      console.log(`🚪 Socket ${socket.id} joined room ${roomName}`);

      if (roomName === 'complaints_agents') {
        broadcastSupportPresence(io, socket);
      }

      if (socket.userId) {
        socket.to(roomName).emit('user_presence', {
          userId: socket.userId,
          status: 'online',
          name: socket.userName,
          avatar: socket.userAvatar,
          role: socket.role,
        });
      }

      emitOnlineUsersInRoom(socket, roomName);

      if (roomName.startsWith('support_')) {
        emitSupportPresenceForRoom(io, socket, roomName);
      }
    });

    socket.on('updateLocation', async (data) => {
      if (!socket.userId || !data) return;
      if (!(await refreshSocketUser(socket))) return;
      if (socket.role !== 'captain') return;

      if (data.shipmentId) {
        const ok = await assertCaptainForShipmentLocation(socket.userId, data.shipmentId);
        if (!ok) return;
        io.to(`shipment_${data.shipmentId}`).emit('locationUpdate', {
          ...data,
          isDriver: true,
        });
      } else if (data.orderId) {
        const ok = await assertCaptainForOrderLocation(socket.userId, data.orderId);
        if (!ok) return;
        io.to(`order_${data.orderId}`).emit('locationUpdate', {
          ...data,
          isDriver: true,
        });
      } else {
        return;
      }

      await handleLocationPersistence(io, socket, data);
    });

    socket.on('typing', (data) => {
      if (!data?.roomName) return;
      if (!socket.rooms.has(data.roomName)) return;
      socket.to(data.roomName).emit('typing', data);
    });

    socket.on('leaveRoom', async (roomName) => {
      await refreshSocketUser(socket);
      socket.leave(roomName);
      if (socket.userId) {
        const isSupport = socket.role === 'admin' || socket.role === 'employee';
        socket.to(roomName).emit('user_presence', {
          userId: socket.userId,
          status: isSupport ? 'left' : 'offline',
          role: socket.role,
        });
      }
      if (roomName === 'complaints_agents') {
        broadcastSupportPresence(io, socket);
      }
    });

    socket.on('disconnecting', async () => {
      await refreshSocketUser(socket);
      if (socket.userId) {
        for (const room of socket.rooms) {
          if (room.startsWith('shipment_') || room.startsWith('support_') || room.startsWith('order_')) {
            socket.to(room).emit('user_presence', {
              userId: socket.userId,
              status: 'offline',
              role: socket.role,
            });
          }
        }
      }
    });

    socket.on('disconnect', async () => {
      await refreshSocketUser(socket);
      if (socket.userId && activeUsers.has(socket.userId)) {
        const sockets = activeUsers.get(socket.userId);
        sockets.delete(socket.id);
        if (sockets.size === 0) activeUsers.delete(socket.userId);
      }
      if (socket.role === 'admin' || socket.role === 'employee') {
        const agentsRoom = io.sockets.adapter.rooms.get('complaints_agents');
        if (!agentsRoom || agentsRoom.size === 0) {
          for (const [roomName] of io.sockets.adapter.rooms) {
            if (roomName.startsWith('support_')) {
              io.to(roomName).emit('support_presence_status', { status: 'offline' });
            }
          }
        }
      }
      console.log('🔌 Socket disconnected:', socket.id);
    });
  });
}

async function canJoinRoom(socket, roomName) {
  const { userId, role } = socket;
  if (roomName === 'complaints_agents') {
    return role === 'admin' || role === 'employee';
  }
  if (roomName.startsWith('shipment_')) {
    const id = roomName.replace('shipment_', '');
    return canJoinShipmentRoom(userId, role, id);
  }
  if (roomName.startsWith('order_')) {
    const id = roomName.replace('order_', '');
    return canJoinOrderRoom(userId, role, id);
  }
  if (roomName.startsWith('support_')) {
    const targetUserId = roomName.replace('support_', '');
    return canJoinSupportRoom(userId, role, targetUserId);
  }
  return false;
}

function emitOnlineUsersInRoom(socket, roomName) {
  const clients = socket.adapter.rooms.get(roomName);
  if (!clients) return;
  const onlineUsers = [];
  for (const clientId of clients) {
    const clientSocket = socket.nsp.sockets.get(clientId);
    if (clientSocket?.userId && clientSocket.userId !== socket.userId) {
      onlineUsers.push(clientSocket.userId);
    }
  }
  if (onlineUsers.length > 0) {
    socket.emit('online_users', onlineUsers);
  }
}

function emitSupportPresenceForRoom(io, socket, roomName) {
  const clients = io.sockets.adapter.rooms.get(roomName);
  const agentsRoom = io.sockets.adapter.rooms.get('complaints_agents');
  const hasAgents = agentsRoom && agentsRoom.size > 0;
  let adminInRoom = false;
  let activeAdminSocket = null;
  if (clients) {
    for (const clientId of clients) {
      const clientSocket = io.sockets.sockets.get(clientId);
      if (
        clientSocket &&
        (clientSocket.role === 'admin' || clientSocket.role === 'employee') &&
        clientSocket.userId !== socket.userId
      ) {
        adminInRoom = true;
        activeAdminSocket = clientSocket;
        break;
      }
    }
  }
  socket.emit('support_presence_status', {
    status: adminInRoom ? 'online' : hasAgents ? 'left' : 'offline',
    name: activeAdminSocket ? activeAdminSocket.userName : null,
    avatar: activeAdminSocket ? activeAdminSocket.userAvatar : null,
  });
}

function broadcastSupportPresence(io, socket) {
  const rooms = io.sockets.adapter.rooms;
  for (const [rName, rBody] of rooms) {
    if (!rName.startsWith('support_')) continue;
    let adminInRoom = false;
    let activeAdminSocket = null;
    for (const clientId of rBody) {
      const clientSocket = io.sockets.sockets.get(clientId);
      if (clientSocket && (clientSocket.role === 'admin' || clientSocket.role === 'employee')) {
        adminInRoom = true;
        activeAdminSocket = clientSocket;
        break;
      }
    }
    io.to(rName).emit('support_presence_status', {
      status: adminInRoom ? 'online' : 'left',
      name: activeAdminSocket ? activeAdminSocket.userName : null,
      avatar: activeAdminSocket ? activeAdminSocket.userAvatar : null,
    });
  }
}

async function handleLocationPersistence(io, socket, data) {
  try {
    const { getPool } = require('../config/db');
    const { sendPushNotification } = require('../utils/notificationHelper');
    const pool = getPool();
    const driverLat = parseFloat(data.latitude);
    const driverLng = parseFloat(data.longitude);
    if (Number.isNaN(driverLat) || Number.isNaN(driverLng)) return;

    await pool.query('UPDATE users SET latitude = ?, longitude = ? WHERE id = ?', [
      driverLat,
      driverLng,
      socket.userId,
    ]);

    if (data.shipmentId) {
      await pool.query(
        `UPDATE shipments 
         SET startLatitude = COALESCE(startLatitude, ?), 
             startLongitude = COALESCE(startLongitude, ?) 
         WHERE id = ? AND captainId = ?`,
        [driverLat, driverLng, data.shipmentId, socket.userId]
      );
      await runProximityLogic(pool, sendPushNotification, data.shipmentId, driverLat, driverLng);
    } else if (data.orderId) {
      await pool.query(
        `UPDATE orders 
         SET startLatitude = COALESCE(startLatitude, ?), 
             startLongitude = COALESCE(startLongitude, ?) 
         WHERE id = ? AND captainId = ?`,
        [driverLat, driverLng, data.orderId, socket.userId]
      );
    }

    io.to(`captain_${socket.userId}`).emit('locationUpdate', {
      userId: socket.userId,
      latitude: driverLat,
      longitude: driverLng,
      shipmentId: data.shipmentId,
      orderId: data.orderId,
      isDriver: true,
    });
  } catch (err) {
    console.error('❌ Error in updateLocation handler:', err);
  }
}

async function runProximityLogic(pool, sendPushNotification, shipmentId, driverLat, driverLng) {
  const PROXIMITY_METERS = 500;
  const haversineMeters = (lat1, lng1, lat2, lng2) => {
    const R = 6371000;
    const toRad = (deg) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  };

  const [shipRows] = await pool.query(
    `SELECT s.id, s.status, s.shipmentNumber,
            s.merchantLatitude, s.merchantLongitude,
            s.toLatitude, s.toLongitude,
            s.pickupNearbyNotified, s.deliveryNearbyNotified,
            m.fcmToken as merchantFcm
     FROM shipments s
     LEFT JOIN users m ON s.merchantId = m.id
     WHERE s.id = ?`,
    [shipmentId]
  );

  if (shipRows.length === 0) return;
  const ship = shipRows[0];

  if (
    ship.status === 'تم قبول العرض' &&
    ship.merchantLatitude &&
    ship.merchantLongitude &&
    !ship.pickupNearbyNotified
  ) {
    const dist = haversineMeters(
      driverLat,
      driverLng,
      parseFloat(ship.merchantLatitude),
      parseFloat(ship.merchantLongitude)
    );
    if (dist <= PROXIMITY_METERS) {
      await pool.query('UPDATE shipments SET pickupNearbyNotified = 1 WHERE id = ?', [ship.id]);
      if (ship.merchantFcm) {
        await sendPushNotification(
          ship.merchantFcm,
          'المندوب في الطريق إليك 🚚',
          'المندوب اقترب من موقع الاستلام وسيصل خلال دقائق.',
          { type: 'captain_nearby_pickup', shipmentId: ship.id.toString(), shipmentNumber: ship.shipmentNumber }
        );
      }
    }
  }

  if (
    ship.status === 'تم التنفيذ' &&
    ship.toLatitude &&
    ship.toLongitude &&
    !ship.deliveryNearbyNotified
  ) {
    const dist = haversineMeters(
      driverLat,
      driverLng,
      parseFloat(ship.toLatitude),
      parseFloat(ship.toLongitude)
    );
    if (dist <= PROXIMITY_METERS) {
      await pool.query('UPDATE shipments SET deliveryNearbyNotified = 1 WHERE id = ?', [ship.id]);
      if (ship.merchantFcm) {
        await sendPushNotification(
          ship.merchantFcm,
          'المندوب وصل قريباً 📦',
          'المندوب اقترب من عنوان التسليم وسيصل خلال دقائق.',
          { type: 'captain_nearby_delivery', shipmentId: ship.id.toString(), shipmentNumber: ship.shipmentNumber }
        );
      }
    }
  }
}

module.exports = { registerSocketHandlers };
