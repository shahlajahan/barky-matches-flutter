const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.cert(
    require("./barkymatches-new-firebase-adminsdk-fbsvc-a59ea693de.json")
  ),
});

const message = {
  token: "dS3fM0fqjE5ug_OrvnZZpi:APA91bF33de8jd9Xw7ntoFnjhDTIKVO-ZeypL4A1m6m3WidhAe9xOBfIKjuCK0j4FMy5pAv-7M-SZqjEVlBuYgYQXyZDuQiG55FTF9GWQSSpC5UN7dbRMbE",
  notification: {
    title: "🐶 BarkyMatches",
    body: "iOS test push (ADMIN SDK)",
  },
  apns: {
    headers: {
      "apns-priority": "10",
    },
    payload: {
      aps: {
        sound: "default",
      },
    },
  },
};

admin
  .messaging()
  .send(message)
  .then((res) => {
    console.log("✅ PUSH SENT:", res);
    process.exit(0);
  })
  .catch((err) => {
    console.error("❌ PUSH ERROR:", err);
    process.exit(1);
  });

