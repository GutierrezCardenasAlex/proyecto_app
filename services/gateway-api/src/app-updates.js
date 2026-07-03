const fs = require("fs/promises");
const path = require("path");

const manifestPath = process.env.APP_UPDATES_MANIFEST_PATH
  ? path.resolve(process.env.APP_UPDATES_MANIFEST_PATH)
  : path.join(__dirname, "app-updates.manifest.json");

let cachedManifest = null;
let cachedManifestMtime = 0;

async function readManifestFile() {
  const stats = await fs.stat(manifestPath);
  const mtime = Number(stats.mtimeMs || 0);
  if (cachedManifest != null && cachedManifestMtime === mtime) {
    return cachedManifest;
  }
  const raw = await fs.readFile(manifestPath, "utf8");
  cachedManifest = JSON.parse(raw);
  cachedManifestMtime = mtime;
  return cachedManifest;
}

async function registerAppUpdatesRoutes(app) {
  app.get("/api/app-updates/manifest", async () => {
    const manifest = await readManifestFile();
    return manifest;
  });

  app.get("/api/app-updates/manifest/:appId/:platform", async (request, reply) => {
    const manifest = await readManifestFile();
    const appId = String(request.params.appId || "").trim();
    const platform = String(request.params.platform || "").trim();
    const appManifest = manifest?.apps?.[appId]?.[platform];
    if (!appManifest) {
      return reply.code(404).send({
        message: "Update manifest not found",
        appId,
        platform,
      });
    }
    return {
      updatedAt: manifest.updatedAt,
      appId,
      platform,
      ...appManifest,
    };
  });
}

module.exports = {
  registerAppUpdatesRoutes,
};
