const Fastify = require("fastify");
const cors = require("@fastify/cors");
const Redis = require("ioredis");
const { Server } = require("socket.io");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3008);
const redis = new Redis(process.env.REDIS_URL);

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  const io = new Server(app.server, {
    cors: {
      origin: true,
      credentials: true
    }
  });

  io.on("connection", (socket) => {
    socket.on("join:trip", (tripId) => socket.join(`trip:${tripId}`));
    socket.on("join:driver", (driverId) => socket.join(`driver:${driverId}`));
    socket.on("leave:trip", (tripId) => socket.leave(`trip:${tripId}`));
    socket.on("leave:driver", (driverId) => socket.leave(`driver:${driverId}`));
    socket.on("join:admin", () => socket.join("admin"));
  });

  app.get("/health", async () => ({ status: "ok", service: "websocket-service" }));

  app.post("/internal/events", async (request) => {
    const { event, room, data } = request.body;
    io.to(room).emit(event, data);
    io.to("admin").emit(event, data);
    await redis.publish("ws-events", JSON.stringify({ event, room, data }));
    return { success: true };
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
