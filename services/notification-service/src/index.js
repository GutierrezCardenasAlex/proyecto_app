const Fastify = require("fastify");
const cors = require("@fastify/cors");
const admin = require("firebase-admin");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3006);

function getFirebaseApp() {
  if (admin.apps.length) {
    return admin.app();
  }

  if (process.env.FCM_PRIVATE_KEY === "demo") {
    return null;
  }

  return admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FCM_PROJECT_ID,
      clientEmail: process.env.FCM_CLIENT_EMAIL,
      privateKey: process.env.FCM_PRIVATE_KEY.replace(/\\n/g, "\n")
    })
  });
}

const pushSchema = z.object({
  token: z.string().min(10),
  title: z.string().min(1),
  body: z.string().min(1),
  data: z.record(z.string()).optional()
});

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  app.get("/health", async () => ({ status: "ok", service: "notification-service" }));

  app.post("/push", async (request) => {
    const payload = pushSchema.parse(request.body);
    const firebaseApp = getFirebaseApp();

    if (!firebaseApp) {
      app.log.warn("Firebase credentials not configured, returning mock notification result");
      return { success: true, mocked: true };
    }

    const response = await admin.messaging().send({
      token: payload.token,
      notification: {
        title: payload.title,
        body: payload.body
      },
      data: payload.data
    });

    return { success: true, messageId: response };
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
