// Обновляет документ config/update в Firestore, чтобы приложение увидело
// новую версию и показало кнопку обновления.
//
// Запускается из GitHub Actions после создания релиза.
// Значения приходят через переменные окружения:
//   FIREBASE_SERVICE_ACCOUNT — JSON сервисного аккаунта
//   VERSION_NAME             — версия для показа, например 1.1.0r
//   VERSION_CODE             — числовой код версии
//   APK_URL                  — прямая ссылка на APK в релизе

const admin = require('firebase-admin');

const {
  FIREBASE_SERVICE_ACCOUNT,
  VERSION_NAME,
  VERSION_CODE,
  APK_URL,
} = process.env;

async function main() {
  if (!FIREBASE_SERVICE_ACCOUNT) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT is not set');
  }
  if (!VERSION_NAME || !VERSION_CODE || !APK_URL) {
    throw new Error('VERSION_NAME, VERSION_CODE and APK_URL are required');
  }

  // Убираем BOM, если он попал в начало строки (Windows/PowerShell).
  const cleaned = FIREBASE_SERVICE_ACCOUNT.replace(/^\uFEFF/, '');
  const serviceAccount = JSON.parse(cleaned);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  await admin.firestore().collection('config').doc('update').set(
    {
      latestVersionCode: parseInt(VERSION_CODE, 10),
      latestVersion: VERSION_NAME,
      apkUrl: APK_URL,
      notes: `Обновление ${VERSION_NAME}`,
    },
    { merge: true },
  );

  console.log(`Firestore updated: ${VERSION_NAME} (${VERSION_CODE}) -> ${APK_URL}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
