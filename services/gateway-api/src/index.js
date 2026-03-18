const Fastify = require("fastify");
const cors = require("@fastify/cors");
const jwt = require("@fastify/jwt");
const proxy = require("@fastify/http-proxy");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3000);

const serviceMap = {
  "/api/auth": process.env.AUTH_SERVICE_URL,
  "/api/drivers": process.env.DRIVER_SERVICE_URL,
  "/api/trips": process.env.TRIP_SERVICE_URL,
  "/api/dispatch": process.env.DISPATCH_SERVICE_URL,
  "/api/locations": process.env.LOCATION_SERVICE_URL,
  "/api/notifications": process.env.NOTIFICATION_SERVICE_URL,
  "/api/admin": process.env.ADMIN_SERVICE_URL
};

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });
  await app.register(jwt, { secret: process.env.JWT_SECRET || "super-secret" });

  app.decorate("authenticate", async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch (error) {
      reply.code(401).send({ message: "Unauthorized" });
    }
  });

  app.get("/health", async () => ({ status: "ok", service: "gateway-api" }));

  for (const [prefix, upstream] of Object.entries(serviceMap)) {
    await app.register(proxy, {
      upstream,
      prefix,
      rewritePrefix: "",
      preHandler: prefix === "/api/auth" ? undefined : app.authenticate
    });
  }

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
