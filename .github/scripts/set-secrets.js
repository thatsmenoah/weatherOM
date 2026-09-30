// Загружает секреты в GitHub Actions (шифрует через libsodium sealed box).
// Значения берутся из переменных окружения и файлов проекта.
const sodium = require('libsodium-wrappers');
const fs = require('fs');
const path = require('path');

const TOKEN = process.env.GH_TOKEN;
const PROJECT_DIR = process.env.PROJECT_DIR;
const OWNER = 'thatsmenoah';
const REPO = 'weatherOM';

async function api(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `token ${TOKEN}`,
      Accept: 'application/vnd.github+json',
      'User-Agent': 'wc',
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    throw new Error(`${method} ${url} -> ${res.status} ${await res.text()}`);
  }
  return res.status === 204 ? null : res.json();
}

async function main() {
  await sodium.ready;

  const key = await api(
    'GET',
    `https://api.github.com/repos/${OWNER}/${REPO}/actions/secrets/public-key`,
  );

  const keystoreB64 = fs
    .readFileSync(path.join(PROJECT_DIR, 'android', 'app', 'weather-cloud-release.jks'))
    .toString('base64');
  const saJson = fs
    .readFileSync(
      path.join(PROJECT_DIR, 'release-builds', 'firebase-service-account.json'),
      'utf8',
    )
    .replace(/^\uFEFF/, ''); // убираем BOM, если есть

  const secrets = {
    KEYSTORE_BASE64: keystoreB64,
    KEYSTORE_PASSWORD: process.env.KEYSTORE_PASSWORD,
    KEY_PASSWORD: process.env.KEYSTORE_PASSWORD,
    KEY_ALIAS: 'weather-cloud',
    OPENWEATHER_API_KEY: process.env.OPENWEATHER_API_KEY,
    OPENCAGE_API_KEY: process.env.OPENCAGE_API_KEY,
    FIREBASE_SERVICE_ACCOUNT: saJson,
  };

  for (const [name, value] of Object.entries(secrets)) {
    const binKey = sodium.from_base64(key.key, sodium.base64_variants.ORIGINAL);
    const encrypted = sodium.crypto_box_seal(sodium.from_string(value), binKey);
    await api('PUT', `https://api.github.com/repos/${OWNER}/${REPO}/actions/secrets/${name}`, {
      encrypted_value: sodium.to_base64(encrypted, sodium.base64_variants.ORIGINAL),
      key_id: key.key_id,
    });
    console.log(`set secret: ${name}`);
  }
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
