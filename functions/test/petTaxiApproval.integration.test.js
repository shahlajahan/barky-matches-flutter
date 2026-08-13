const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { test, before } = require("node:test");
const {
  buildBusinessPublicProjection,
  synchronizeBusinessPublicProjection,
} = require("../src/publicProjections");
const {
  evaluatePetTaxiDocumentExpiry,
  petTaxiDocumentVersionToken,
  petTaxiReminderDocId,
  petTaxiExpiryReminderFor,
  processPetTaxiExpiryReminders,
} = require("../src/petTaxiApproval");

if (!admin.apps.length) admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
const db = admin.firestore();
const functions = require("../index");

const testRunId = `${Date.now()}-${process.pid}-${crypto.randomBytes(4).toString("hex")}`;
const adminUid = `pet-taxi-approval-admin-${testRunId}`;
let sequence = 0;
const requiredDocs = ["taxPlate", "vehicleRegistration", "driverLicense", "trafficInsurance"];
const complianceFlags = ["petSafetyEquipmentConfirmed", "hygieneSanitationConfirmed", "driverLicenseValidConfirmed", "vehicleRegistrationConfirmed", "trafficInsuranceConfirmed", "taxResponsibilityConfirmed", "transportRulesConfirmed"];

before(async () => {
  await db.collection("users").doc(adminUid).set({ role: "admin" });
});

function fixture({
  sectors = ["pet_taxi"],
  documentsApproved = false,
  flagsApproved = false,
  expiryOverrides = {},
  legacyExpiryKeys = [],
} = {}) {
  sequence += 1;
  const businessId = `pet-taxi-approval-business-${testRunId}-${sequence}`;
  const ownerUid = `pet-taxi-approval-owner-${testRunId}-${sequence}`;
  const documents = Object.fromEntries(requiredDocs.map((key) => {
    const document = {
      url: `https://example.test/${key}.pdf`,
      storagePath: `business_sector_docs/${ownerUid}/pet_taxi/${key}/file.pdf`,
      status: documentsApproved ? "approved" : "pending_review",
      verified: documentsApproved,
    };
    if (key === "driverLicense" || key === "trafficInsurance") {
      const expiry = Object.prototype.hasOwnProperty.call(expiryOverrides, key)
        ? expiryOverrides[key]
        : "2099-01-01";
      if (expiry !== null) {
        const field = legacyExpiryKeys.includes(key)
          ? "expiryDate"
          : key === "driverLicense"
            ? "driverLicenseExpiryDate"
            : "trafficInsuranceExpiryDate";
        document[field] = expiry;
      }
    }
    return [key, document];
  }));
  const compliance = Object.fromEntries(complianceFlags.map((key) => [key, flagsApproved]));
  compliance.status = "pending_review";
  compliance.manualReviewRequired = true;
  return {
    businessId,
    ownerUid,
    business: {
      ownerUid,
      status: "approved",
      sectors,
      published: false,
      verification: { isVerified: true },
      sectorData: {
        pet_taxi: {
          documents,
          compliance,
          isActive: false,
          published: false,
        },
      },
    },
  };
}

async function seed(fixtureData) {
  await db.collection("users").doc(fixtureData.ownerUid).set({ role: "user" });
  await db.collection("businesses").doc(fixtureData.businessId).set(fixtureData.business);
}

async function call(name, auth, data) {
  return functions[name].run({ auth, data });
}

test("non-admin rejection is refused and admin rejection requires a reason", async () => {
  const item = fixture();
  await seed(item);
  await assert.rejects(
    call("reviewPetTaxiDocument", { uid: item.ownerUid }, {
      businessId: item.businessId,
      documentKey: "taxPlate",
      action: "rejected",
      reason: "Unreadable",
    }),
    /Admin only/
  );
  await assert.rejects(
    call("reviewPetTaxiDocument", { uid: adminUid }, {
      businessId: item.businessId,
      documentKey: "taxPlate",
      action: "rejected",
    }),
    /Rejection reason is required/
  );
  await call("reviewPetTaxiDocument", { uid: adminUid }, {
    businessId: item.businessId,
    documentKey: "taxPlate",
    action: "rejected",
    reason: "Unreadable",
  });
  assert.equal((await db.collection("businesses").doc(item.businessId).get()).data().sectorData.pet_taxi.documents.taxPlate.status, "rejected");
});

test("re-upload resets rejected document and illegal direct approval is refused", async () => {
  const item = fixture();
  await seed(item);
  await call("reviewPetTaxiDocument", { uid: adminUid }, {
    businessId: item.businessId, documentKey: "taxPlate", action: "rejected", reason: "Replace this file",
  });
  await assert.rejects(
    call("reviewPetTaxiDocument", { uid: adminUid }, {
      businessId: item.businessId, documentKey: "taxPlate", action: "approved",
    }),
    /Illegal document state transition/
  );
  await call("resubmitPetTaxiDocument", { uid: item.ownerUid }, {
    businessId: item.businessId,
    documentKey: "taxPlate",
    document: {
      url: "https://example.test/taxPlate-replacement.pdf",
      storagePath: `business_sector_docs/${item.ownerUid}/pet_taxi/taxPlate/replacement.pdf`,
      fileName: "replacement.pdf",
      contentType: "application/pdf",
    },
  });
  await call("reviewPetTaxiDocument", { uid: adminUid }, {
    businessId: item.businessId, documentKey: "taxPlate", action: "approved",
  });
  const doc = (await db.collection("businesses").doc(item.businessId).get()).data().sectorData.pet_taxi.documents.taxPlate;
  assert.equal(doc.status, "approved");
  assert.equal(doc.verified, true);
});

async function rejectDocument(item, documentKey) {
  await call("reviewPetTaxiDocument", { uid: adminUid }, {
    businessId: item.businessId,
    documentKey,
    action: "rejected",
    reason: "Replacement required",
  });
}

function replacementDocument(item, documentKey, expiryField, expiry = "2099-05-30") {
  return {
    url: `https://example.test/${documentKey}-replacement.pdf`,
    storagePath: `business_sector_docs/${item.ownerUid}/pet_taxi/${documentKey}/replacement.pdf`,
    fileName: "replacement.pdf",
    contentType: "application/pdf",
    ...(expiryField ? { [expiryField]: expiry } : {}),
  };
}

test("resubmission accepts only rejected documents and resets downstream state", async () => {
  for (const status of ["pending_review", "approved"]) {
    const item = fixture({ documentsApproved: status === "approved", flagsApproved: true });
    await seed(item);
    if (status === "approved") {
      await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
    }
    await assert.rejects(
      call("resubmitPetTaxiDocument", { uid: item.ownerUid }, {
        businessId: item.businessId,
        documentKey: "taxPlate",
        document: replacementDocument(item, "taxPlate"),
      }),
      /Only rejected Pet Taxi documents can be resubmitted/
    );
  }

  const item = fixture();
  await seed(item);
  await rejectDocument(item, "taxPlate");
  await call("resubmitPetTaxiDocument", { uid: item.ownerUid }, {
    businessId: item.businessId,
    documentKey: "taxPlate",
    document: replacementDocument(item, "taxPlate"),
  });
  const data = (await db.collection("businesses").doc(item.businessId).get()).data();
  const document = data.sectorData.pet_taxi.documents.taxPlate;
  assert.equal(document.status, "pending_review");
  assert.equal(document.verified, false);
  assert.equal(document.rejectionReason, null);
  assert.equal(data.sectorData.pet_taxi.compliance.status, "pending_review");
  assert.equal(data.sectorData.pet_taxi.isActive, false);
  assert.equal(data.sectorData.pet_taxi.published, false);
  assert.equal(data.published, false);
});

test("expiring replacements require valid canonical expiry and remove stale fallback", async () => {
  for (const [documentKey, expiryField] of [
    ["driverLicense", "driverLicenseExpiryDate"],
    ["trafficInsurance", "trafficInsuranceExpiryDate"],
  ]) {
    for (const expiry of [undefined, "not-a-date", "2000-01-01"]) {
      const item = fixture();
      await seed(item);
      await rejectDocument(item, documentKey);
      const document = replacementDocument(item, documentKey, expiryField, expiry);
      if (expiry === undefined) delete document[expiryField];
      await assert.rejects(
        call("resubmitPetTaxiDocument", { uid: item.ownerUid }, {
          businessId: item.businessId,
          documentKey,
          document,
        }),
        expiry === undefined
          ? /missing its expiry date/
          : expiry === "not-a-date"
            ? /invalid expiry date/
            : /has expired/
      );
    }

    const item = fixture({
      expiryOverrides: { [documentKey]: "2000-01-01" },
    });
    await seed(item);
    await rejectDocument(item, documentKey);
    const document = {
      ...replacementDocument(item, documentKey, expiryField, "2099-05-30"),
      expiryDate: "2000-01-01",
    };
    await call("resubmitPetTaxiDocument", { uid: item.ownerUid }, {
      businessId: item.businessId,
      documentKey,
      document,
    });
    const stored = (await db.collection("businesses").doc(item.businessId).get())
      .data().sectorData.pet_taxi.documents[documentKey];
    assert.equal(stored[expiryField], "2099-05-30");
    assert.equal(stored.expiryDate, undefined);
  }
});

test("non-expiring document replacements do not require expiry metadata", async () => {
  for (const documentKey of ["taxPlate", "businessRegistration", "vehicleRegistration"]) {
    const item = fixture();
    await seed(item);
    await rejectDocument(item, documentKey);
    await call("resubmitPetTaxiDocument", { uid: item.ownerUid }, {
      businessId: item.businessId,
      documentKey,
      document: replacementDocument(item, documentKey),
    });
    const stored = (await db.collection("businesses").doc(item.businessId).get())
      .data().sectorData.pet_taxi.documents[documentKey];
    assert.equal(stored.status, "pending_review");
    assert.equal(stored.verified, false);
  }
});

test("Pet Taxi resubmission rejects unsupported document formats", async () => {
  const item = fixture();
  await seed(item);
  await rejectDocument(item, "taxPlate");
  await assert.rejects(
    call("resubmitPetTaxiDocument", { uid: item.ownerUid }, {
      businessId: item.businessId,
      documentKey: "taxPlate",
      document: {
        url: "https://example.test/taxPlate.webp",
        storagePath: `business_sector_docs/${item.ownerUid}/pet_taxi/taxPlate/replacement.webp`,
        fileName: "replacement.webp",
        contentType: "image/webp",
      },
    }),
    /must be PDF, JPG, JPEG, or PNG/
  );
});

test("approved documents cannot be reviewed again and rejected documents cannot be approved directly", async () => {
  const approved = fixture({ documentsApproved: true });
  await seed(approved);
  await assert.rejects(
    call("reviewPetTaxiDocument", { uid: adminUid }, {
      businessId: approved.businessId,
      documentKey: "driverLicense",
      action: "approved",
    }),
    /Illegal document state transition/
  );

  const rejected = fixture();
  await seed(rejected);
  await rejectDocument(rejected, "driverLicense");
  await assert.rejects(
    call("reviewPetTaxiDocument", { uid: adminUid }, {
      businessId: rejected.businessId,
      documentKey: "driverLicense",
      action: "approved",
    }),
    /Illegal document state transition/
  );
});

test("valid replacement completes driver-license and traffic-insurance recovery", async () => {
  for (const [documentKey, expiryField] of [
    ["driverLicense", "driverLicenseExpiryDate"],
    ["trafficInsurance", "trafficInsuranceExpiryDate"],
  ]) {
    const item = fixture({
      flagsApproved: true,
      expiryOverrides: { [documentKey]: "2000-01-01" },
    });
    await seed(item);
    await rejectDocument(item, documentKey);
    await call("resubmitPetTaxiDocument", { uid: item.ownerUid }, {
      businessId: item.businessId,
      documentKey,
      document: replacementDocument(item, documentKey, expiryField),
    });
    await call("reviewPetTaxiDocument", { uid: adminUid }, {
      businessId: item.businessId,
      documentKey,
      action: "approved",
    });
    for (const otherKey of requiredDocs.filter((key) => key !== documentKey)) {
      await call("reviewPetTaxiDocument", { uid: adminUid }, {
        businessId: item.businessId,
        documentKey: otherKey,
        action: "approved",
      });
    }
    await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
    await call("activatePetTaxiPublication", { uid: adminUid }, { businessId: item.businessId });
    const data = (await db.collection("businesses").doc(item.businessId).get()).data();
    assert.equal(data.published, true);
    assert.equal(data.sectorData.pet_taxi.isActive, true);
    assert.equal(data.sectorData.pet_taxi.documents[documentKey][expiryField], "2099-05-30");
  }
});

test("Pet Taxi expiry reminder thresholds are deterministic and deduplicated", async () => {
  const now = new Date("2026-08-10T12:00:00.000Z");
  assert.equal(
    petTaxiExpiryReminderFor("driverLicense", { driverLicenseExpiryDate: "2026-09-09" }, now).daysUntilExpiry,
    30
  );
  assert.equal(
    petTaxiExpiryReminderFor("driverLicense", { driverLicenseExpiryDate: "2026-08-10" }, now).daysUntilExpiry,
    0
  );
  assert.equal(
    petTaxiExpiryReminderFor("driverLicense", { driverLicenseExpiryDate: "2026-08-09" }, now).daysUntilExpiry,
    -1
  );
  assert.equal(petTaxiExpiryReminderFor("taxPlate", {}, now), null);

  const item = fixture({ expiryOverrides: { driverLicense: "2026-09-09" } });
  await seed(item);
  await db.collection("users").doc(item.ownerUid).update({ fcmToken: "owner-token" });
  await db.collection("users").doc(adminUid).update({ fcmToken: "admin-token" });
  const pushes = [];
  const first = await processPetTaxiExpiryReminders({
    db,
    now,
    sendPush: async (payload) => pushes.push(payload),
  });
  assert.equal(first.created, 2);
  assert.equal(pushes.length, 2);
  const second = await processPetTaxiExpiryReminders({
    db,
    now,
    sendPush: async (payload) => pushes.push(payload),
  });
  assert.equal(second.created, 0);
  assert.equal(pushes.length, 2);
});

test("Pet Taxi expiry reminders support every configured threshold", () => {
  const now = new Date("2026-08-10T12:00:00.000Z");
  for (const days of [30, 14, 7, 3, 1, 0, -1]) {
    const expiry = new Date(now.getTime() + days * 24 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
    assert.equal(
      petTaxiExpiryReminderFor(
        "trafficInsurance",
        { trafficInsuranceExpiryDate: expiry },
        now
      ).daysUntilExpiry,
      days
    );
  }
  assert.equal(
    petTaxiExpiryReminderFor(
      "driverLicense",
      { driverLicenseExpiryDate: "2026-08-12" },
      now
    ),
    null
  );
  assert.equal(
    petTaxiExpiryReminderFor(
      "driverLicense",
      { driverLicenseExpiryDate: "not-a-date" },
      now
    ),
    null
  );
  assert.equal(petTaxiExpiryReminderFor("driverLicense", {}, now), null);
});

test("Pet Taxi reminder deduplication is isolated per replacement version and recipient", async () => {
  const item = fixture({
    expiryOverrides: {
      driverLicense: "2026-09-09",
      trafficInsurance: "2099-09-09",
    },
  });
  await seed(item);
  const secondAdminUid = `${adminUid}-2`;
  await db.collection("users").doc(secondAdminUid).set({ role: "admin" });

  const versionA = (await db.collection("businesses").doc(item.businessId).get())
    .data().sectorData.pet_taxi.documents.driverLicense;
  const notificationCount = async (businessId, documentKey) => (await db.collection("notifications")
    .where("businessId", "==", businessId)
    .where("documentKey", "==", documentKey)
    .get()).size;
  assert.notEqual(
    petTaxiDocumentVersionToken(versionA),
    petTaxiDocumentVersionToken({ ...versionA, storagePath: `${versionA.storagePath}-replacement` })
  );

  const first = await processPetTaxiExpiryReminders({
    db,
    now: new Date("2026-08-10T12:00:00.000Z"),
  });
  const firstForItem = await notificationCount(item.businessId, "driverLicense");
  assert.ok(firstForItem > 1);

  const repeated = await processPetTaxiExpiryReminders({
    db,
    now: new Date("2026-08-10T12:00:00.000Z"),
  });
  assert.equal(await notificationCount(item.businessId, "driverLicense"), firstForItem);

  const replacement = {
    ...versionA,
    storagePath: `${versionA.storagePath}-version-b`,
    url: "https://example.test/driver-license-version-b.pdf",
    driverLicenseExpiryDate: "2027-09-09",
  };
  await db.collection("businesses").doc(item.businessId).update({
    "sectorData.pet_taxi.documents.driverLicense": replacement,
  });

  await processPetTaxiExpiryReminders({
    db,
    now: new Date("2026-09-02T12:00:00.000Z"),
  });
  assert.equal(await notificationCount(item.businessId, "driverLicense"), firstForItem);

  const newVersion = await processPetTaxiExpiryReminders({
    db,
    now: new Date("2027-08-10T12:00:00.000Z"),
  });
  const newVersionForItem = await notificationCount(item.businessId, "driverLicense");
  assert.equal(newVersionForItem, firstForItem * 2);

  const newVersionRepeated = await processPetTaxiExpiryReminders({
    db,
    now: new Date("2027-08-10T12:00:00.000Z"),
  });
  assert.equal(await notificationCount(item.businessId, "driverLicense"), newVersionForItem);

  assert.equal(
    petTaxiReminderDocId(item.businessId, "driverLicense", "version-a", "30", item.ownerUid)
      .includes(versionA.storagePath),
    false
  );

  const insuranceItem = fixture({
    expiryOverrides: {
      driverLicense: "2099-09-09",
      trafficInsurance: "2026-09-09",
    },
  });
  await seed(insuranceItem);
  const insuranceFirst = await processPetTaxiExpiryReminders({
    db,
    now: new Date("2026-08-10T12:00:00.000Z"),
  });
  const insuranceFirstForItem = await notificationCount(insuranceItem.businessId, "trafficInsurance");
  assert.ok(insuranceFirstForItem > 1);
  const insuranceVersion = (await db.collection("businesses").doc(insuranceItem.businessId).get())
    .data().sectorData.pet_taxi.documents.trafficInsurance;
  await db.collection("businesses").doc(insuranceItem.businessId).update({
    "sectorData.pet_taxi.documents.trafficInsurance": {
      ...insuranceVersion,
      storagePath: `${insuranceVersion.storagePath}-version-b`,
      trafficInsuranceExpiryDate: "2027-09-09",
    },
  });
  const insuranceNewVersion = await processPetTaxiExpiryReminders({
    db,
    now: new Date("2027-08-10T12:00:00.000Z"),
  });
  assert.equal(
    await notificationCount(insuranceItem.businessId, "trafficInsurance"),
    insuranceFirstForItem * 2
  );
});

test("Pet Taxi reminder persistence survives missing tokens and FCM failure", async () => {
  const item = fixture({ expiryOverrides: { driverLicense: "2026-09-09" } });
  await seed(item);
  const secondAdminUid = `${adminUid}-3`;
  await db.collection("users").doc(secondAdminUid).set({ role: "admin", fcmToken: "admin-3-token" });

  await assert.rejects(
    processPetTaxiExpiryReminders({
      db,
      now: new Date("2026-08-10T12:00:00.000Z"),
      sendPush: async ({ userId }) => {
        if (userId === adminUid) throw new Error("FCM unavailable");
      },
    }),
    /FCM unavailable/
  );

  await processPetTaxiExpiryReminders({
    db,
    now: new Date("2026-08-10T12:00:00.000Z"),
  });
  const notifications = await db.collection("notifications")
    .where("businessId", "==", item.businessId)
    .where("documentKey", "==", "driverLicense")
    .get();
  const adminCount = (await db.collection("users").where("role", "==", "admin").get()).size;
  assert.equal(notifications.size, adminCount + 1);
});

test("valid expiring documents can be approved", async () => {
  for (const documentKey of ["driverLicense", "trafficInsurance"]) {
    const item = fixture();
    await seed(item);
    await call("reviewPetTaxiDocument", { uid: adminUid }, {
      businessId: item.businessId,
      documentKey,
      action: "approved",
    });
    const document = (await db.collection("businesses").doc(item.businessId).get())
      .data().sectorData.pet_taxi.documents[documentKey];
    assert.equal(document.status, "approved");
    assert.equal(document.verified, true);
  }
});

test("expired expiring documents cannot be approved but can be rejected", async () => {
  for (const documentKey of ["driverLicense", "trafficInsurance"]) {
    const item = fixture({ expiryOverrides: { [documentKey]: "2000-01-01" } });
    await seed(item);
    await assert.rejects(
      call("reviewPetTaxiDocument", { uid: adminUid }, {
        businessId: item.businessId,
        documentKey,
        action: "approved",
      }),
      /has expired/
    );
    await call("reviewPetTaxiDocument", { uid: adminUid }, {
      businessId: item.businessId,
      documentKey,
      action: "rejected",
      reason: "Expired document",
    });
    const document = (await db.collection("businesses").doc(item.businessId).get())
      .data().sectorData.pet_taxi.documents[documentKey];
    assert.equal(document.status, "rejected");
    assert.equal(document.verified, false);
  }
});

test("missing and malformed expiring document dates cannot be approved", async () => {
  for (const expiry of [null, "not-a-date"]) {
    for (const documentKey of ["driverLicense", "trafficInsurance"]) {
      const item = fixture({ expiryOverrides: { [documentKey]: expiry } });
      await seed(item);
      await assert.rejects(
        call("reviewPetTaxiDocument", { uid: adminUid }, {
          businessId: item.businessId,
          documentKey,
          action: "approved",
        }),
        expiry === null ? /missing its expiry date/ : /invalid expiry date/
      );
    }
  }
});

test("compliance re-checks expiring documents at approval time", async () => {
  for (const documentKey of ["driverLicense", "trafficInsurance"]) {
    const item = fixture({ documentsApproved: true, flagsApproved: true });
    await seed(item);
    const field = documentKey === "driverLicense"
      ? "driverLicenseExpiryDate"
      : "trafficInsuranceExpiryDate";
    await db.collection("businesses").doc(item.businessId).update({
      [`sectorData.pet_taxi.documents.${documentKey}.${field}`]: "2000-01-01",
    });
    await assert.rejects(
      call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId }),
      /requirements are incomplete/
    );
  }
});

test("publication re-checks expiring documents immediately before activation", async () => {
  for (const documentKey of ["driverLicense", "trafficInsurance"]) {
    const item = fixture({ documentsApproved: true, flagsApproved: true });
    await seed(item);
    await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
    const field = documentKey === "driverLicense"
      ? "driverLicenseExpiryDate"
      : "trafficInsuranceExpiryDate";
    await db.collection("businesses").doc(item.businessId).update({
      [`sectorData.pet_taxi.documents.${documentKey}.${field}`]: "2000-01-01",
    });
    await assert.rejects(
      call("activatePetTaxiPublication", { uid: adminUid }, { businessId: item.businessId }),
      /compliance approval is required/
    );
    const data = (await db.collection("businesses").doc(item.businessId).get()).data();
    assert.equal(data.published, false);
    assert.equal(data.sectorData.pet_taxi.isActive, false);
    assert.equal(data.sectorData.pet_taxi.published, false);
  }
});

test("legacy expiry fallback and canonical precedence are deterministic", () => {
  const now = new Date("2026-08-10T12:00:00.000Z");
  assert.equal(
    evaluatePetTaxiDocumentExpiry(
      "driverLicense",
      { expiryDate: "2099-01-01" },
      now
    ).valid,
    true
  );
  assert.equal(
    evaluatePetTaxiDocumentExpiry(
      "trafficInsurance",
      { expiryDate: "2099-01-01" },
      now
    ).valid,
    true
  );
  assert.equal(
    evaluatePetTaxiDocumentExpiry(
      "driverLicense",
      { driverLicenseExpiryDate: "2000-01-01", expiryDate: "2099-01-01" },
      now
    ).reason,
    "expired"
  );
  assert.equal(
    evaluatePetTaxiDocumentExpiry(
      "trafficInsurance",
      { trafficInsuranceExpiryDate: "2099-01-01", expiryDate: "2000-01-01" },
      now
    ).valid,
    true
  );
});

test("date-only expiry is valid through its stated calendar date and other documents are unaffected", () => {
  const duringDate = new Date("2026-08-10T12:00:00.000Z");
  const afterDate = new Date("2026-08-11T00:00:00.000Z");
  assert.equal(
    evaluatePetTaxiDocumentExpiry(
      "driverLicense",
      { driverLicenseExpiryDate: "2026-08-10" },
      duringDate
    ).valid,
    true
  );
  assert.equal(
    evaluatePetTaxiDocumentExpiry(
      "driverLicense",
      { driverLicenseExpiryDate: "2026-08-10" },
      afterDate
    ).valid,
    false
  );
  assert.equal(
    evaluatePetTaxiDocumentExpiry(
      "trafficInsurance",
      { trafficInsuranceExpiryDate: "2026-08-10T00:00:00.000" },
      duringDate
    ).valid,
    true
  );
  for (const documentKey of ["taxPlate", "businessRegistration", "vehicleRegistration"]) {
    assert.equal(
      evaluatePetTaxiDocumentExpiry(documentKey, {}, afterDate).valid,
      true
    );
  }
});

test("compliance requires every document and mandatory condition", async () => {
  const pending = fixture({ documentsApproved: false, flagsApproved: true });
  await seed(pending);
  await assert.rejects(
    call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: pending.businessId }),
    /requirements are incomplete/
  );

  const rejected = fixture({ documentsApproved: true, flagsApproved: true });
  await seed(rejected);
  await db.collection("businesses").doc(rejected.businessId).update({
    "sectorData.pet_taxi.documents.taxPlate.status": "rejected",
    "sectorData.pet_taxi.documents.taxPlate.verified": false,
  });
  await assert.rejects(
    call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: rejected.businessId }),
    /requirements are incomplete/
  );

  const valid = fixture({ documentsApproved: true, flagsApproved: true });
  await seed(valid);
  await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: valid.businessId });
  const taxi = (await db.collection("businesses").doc(valid.businessId).get()).data().sectorData.pet_taxi;
  assert.equal(taxi.compliance.status, "approved");
  assert.equal(taxi.compliance.manualReviewRequired, false);
});

test("publication requires compliance and approved root, then activates single-sector Pet Taxi", async () => {
  const unapproved = fixture({ documentsApproved: true, flagsApproved: true });
  unapproved.business.status = "pending_review";
  await seed(unapproved);
  await assert.rejects(
    call("activatePetTaxiPublication", { uid: adminUid }, { businessId: unapproved.businessId }),
    /Root business must be approved/
  );

  const item = fixture({ documentsApproved: true, flagsApproved: true });
  await seed(item);
  await assert.rejects(
    call("activatePetTaxiPublication", { uid: adminUid }, { businessId: item.businessId }),
    /compliance approval is required/
  );
  await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
  await call("activatePetTaxiPublication", { uid: adminUid }, { businessId: item.businessId });
  const data = (await db.collection("businesses").doc(item.businessId).get()).data();
  assert.equal(data.published, true);
  assert.equal(data.sectorData.pet_taxi.isActive, true);
  assert.equal(data.sectorData.pet_taxi.published, true);

  await synchronizeBusinessPublicProjection({
    params: { businessId: item.businessId },
    data: { after: { exists: true, data: () => data } },
  }, db);
  const publicData = (await db.collection("businesses_public").doc(item.businessId).get()).data();
  assert.equal(publicData.status, "approved");
  assert.equal(publicData.publicSectorData.pet_taxi.documents, undefined);
  assert.equal(publicData.publicSectorData.pet_taxi.compliance, undefined);
});

test("repeated compliance approval preserves an already activated lifecycle", async () => {
  const item = fixture({ documentsApproved: true, flagsApproved: true });
  await seed(item);

  await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
  let data = (await db.collection("businesses").doc(item.businessId).get()).data();
  assert.equal(data.sectorData.pet_taxi.compliance.status, "approved");
  assert.equal(data.sectorData.pet_taxi.isActive, false);
  assert.equal(data.sectorData.pet_taxi.published, false);
  assert.equal(data.published, false);

  await call("activatePetTaxiPublication", { uid: adminUid }, { businessId: item.businessId });
  data = (await db.collection("businesses").doc(item.businessId).get()).data();
  const activatedAt = data.sectorData.pet_taxi.activatedAt;
  const activatedBy = data.sectorData.pet_taxi.activatedBy;
  assert.equal(data.sectorData.pet_taxi.isActive, true);
  assert.equal(data.sectorData.pet_taxi.published, true);
  assert.equal(data.published, true);

  await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
  data = (await db.collection("businesses").doc(item.businessId).get()).data();
  assert.equal(data.sectorData.pet_taxi.compliance.status, "approved");
  assert.equal(data.sectorData.pet_taxi.isActive, true);
  assert.equal(data.sectorData.pet_taxi.published, true);
  assert.equal(data.published, true);
  assert.deepEqual(data.sectorData.pet_taxi.activatedAt, activatedAt);
  assert.equal(data.sectorData.pet_taxi.activatedBy, activatedBy);
});

test("repeated compliance approval before activation remains inactive and unpublished", async () => {
  const item = fixture({ documentsApproved: true, flagsApproved: true });
  await seed(item);

  await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
  await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
  const data = (await db.collection("businesses").doc(item.businessId).get()).data();
  assert.equal(data.sectorData.pet_taxi.compliance.status, "approved");
  assert.equal(data.sectorData.pet_taxi.isActive, false);
  assert.equal(data.sectorData.pet_taxi.published, false);
  assert.equal(data.published, false);
});

test("multi-sector publication is blocked to preserve root publication isolation", async () => {
  const item = fixture({ sectors: ["pet_taxi", "groomer"], documentsApproved: true, flagsApproved: true });
  item.business.published = true;
  await seed(item);
  await call("approvePetTaxiCompliance", { uid: adminUid }, { businessId: item.businessId });
  assert.equal((await db.collection("businesses").doc(item.businessId).get()).data().published, true);
  await assert.rejects(
    call("activatePetTaxiPublication", { uid: adminUid }, { businessId: item.businessId }),
    /multi-sector businesses/
  );
});

test("public projection allowlist excludes documents and compliance fields", () => {
  const projection = buildBusinessPublicProjection("taxi-1", fixture({ documentsApproved: true, flagsApproved: true }).business);
  const publicTaxi = projection.publicSectorData.pet_taxi;
  assert.equal(publicTaxi.documents, undefined);
  assert.equal(publicTaxi.compliance, undefined);
  assert.equal(publicTaxi.ownerUid, undefined);
});
