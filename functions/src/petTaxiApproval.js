const admin = require("firebase-admin");
const crypto = require("crypto");
const { HttpsError } = require("firebase-functions/v2/https");

const REQUIRED_PET_TAXI_DOCUMENTS = [
  "taxPlate",
  "vehicleRegistration",
  "driverLicense",
  "trafficInsurance",
];

const REQUIRED_PET_TAXI_COMPLIANCE_FLAGS = [
  "petSafetyEquipmentConfirmed",
  "hygieneSanitationConfirmed",
  "driverLicenseValidConfirmed",
  "vehicleRegistrationConfirmed",
  "trafficInsuranceConfirmed",
  "taxResponsibilityConfirmed",
  "transportRulesConfirmed",
];

const PET_TAXI_EXPIRY_FIELDS = {
  driverLicense: "driverLicenseExpiryDate",
  trafficInsurance: "trafficInsuranceExpiryDate",
};

const PET_TAXI_EXPIRY_REMINDER_DAYS = [30, 14, 7, 3, 1, 0, -1];
const PET_TAXI_DOCUMENT_CONTENT_TYPES = {
  pdf: "application/pdf",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
};

function cloneMap(value) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? { ...value }
    : {};
}

function expiryValueForDocument(documentKey, document = {}) {
  const canonicalField = PET_TAXI_EXPIRY_FIELDS[documentKey];
  if (!canonicalField) return null;
  return document[canonicalField] ?? document.expiryDate;
}

function parseExpiryDate(value) {
  if (value == null) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value?.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }
  if (typeof value === "number") {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  const text = String(value).trim();
  if (!text) return null;

  // Expiry values represent calendar dates. This includes the ISO-midnight
  // strings written by the registration and replacement UIs.
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})(.*)$/.exec(text);
  if (dateOnly) {
    const year = Number(dateOnly[1]);
    const month = Number(dateOnly[2]);
    const day = Number(dateOnly[3]);
    const calendarDate = new Date(Date.UTC(year, month - 1, day));
    if (
      calendarDate.getUTCFullYear() !== year ||
      calendarDate.getUTCMonth() !== month - 1 ||
      calendarDate.getUTCDate() !== day
    ) {
      return null;
    }
    if (dateOnly[4] && Number.isNaN(new Date(text).getTime())) return null;
    return new Date(Date.UTC(year, month - 1, day + 1));
  }

  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function evaluatePetTaxiDocumentExpiry(documentKey, document = {}, now = new Date()) {
  const canonicalField = PET_TAXI_EXPIRY_FIELDS[documentKey];
  if (!canonicalField) {
    return { required: false, valid: true, reason: null };
  }

  const rawValue = expiryValueForDocument(documentKey, document);
  if (rawValue == null || String(rawValue).trim() === "") {
    return { required: true, valid: false, reason: "missing_expiry" };
  }

  const expiryDate = parseExpiryDate(rawValue);
  if (!expiryDate) {
    return { required: true, valid: false, reason: "malformed_expiry" };
  }

  return {
    required: true,
    valid: now < expiryDate,
    reason: now < expiryDate ? null : "expired",
    expiryDate,
  };
}

function assertPetTaxiDocumentExpiryValid(documentKey, document, now = new Date()) {
  const result = evaluatePetTaxiDocumentExpiry(documentKey, document, now);
  if (!result.valid) {
    const reason = result.reason === "expired"
      ? "has expired"
      : result.reason === "malformed_expiry"
        ? "has an invalid expiry date"
        : "is missing its expiry date";
    throw new HttpsError(
      "failed-precondition",
      `Pet Taxi ${documentKey} ${reason}`
    );
  }
  return result;
}

function utcCalendarDate(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function expiryCalendarDate(documentKey, document = {}) {
  const rawValue = expiryValueForDocument(documentKey, document);
  if (rawValue == null) return null;
  const text = String(rawValue).trim();
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})/.exec(text);
  if (dateOnly) {
    const year = Number(dateOnly[1]);
    const month = Number(dateOnly[2]);
    const day = Number(dateOnly[3]);
    const date = new Date(Date.UTC(year, month - 1, day));
    if (
      date.getUTCFullYear() !== year ||
      date.getUTCMonth() !== month - 1 ||
      date.getUTCDate() !== day
    ) return null;
    return date;
  }
  const parsed = parseExpiryDate(rawValue);
  return parsed ? utcCalendarDate(parsed) : null;
}

function petTaxiExpiryReminderFor(documentKey, document = {}, now = new Date()) {
  if (!PET_TAXI_EXPIRY_FIELDS[documentKey]) return null;
  if (!document || document.status === "rejected") return null;
  const expiryDay = expiryCalendarDate(documentKey, document);
  if (!expiryDay) return null;
  const today = utcCalendarDate(now);
  const daysUntilExpiry = Math.round(
    (expiryDay.getTime() - today.getTime()) / (24 * 60 * 60 * 1000)
  );
  if (!PET_TAXI_EXPIRY_REMINDER_DAYS.includes(daysUntilExpiry)) return null;
  return { daysUntilExpiry, expiryDay };
}

function petTaxiExpiryReminderMessage(documentKey, daysUntilExpiry, locale = "en") {
  const language = String(locale || "en").toLowerCase().split(/[-_]/)[0];
  const labels = {
    driverLicense: {
      en: "Driver license",
      tr: "Sürücü belgesi",
      fa: "گواهینامه رانندگی",
      ru: "Водительское удостоверение",
    },
    trafficInsurance: {
      en: "Traffic insurance",
      tr: "Trafik sigortası",
      fa: "بیمه شخص ثالث",
      ru: "Страховка автомобиля",
    },
  };
  const copy = {
    en: {
      title: "Pet Taxi document expiry reminder",
      days: (label, days) => `${label} expires in ${days} days. Please upload a valid replacement if needed.`,
      today: (label) => `${label} expires today. Please upload a valid replacement.`,
      expired: (label) => `${label} has expired. Please review the replacement workflow.`,
    },
    tr: {
      title: "Pet Taksi belge son kullanma hatırlatması",
      days: (label, days) => `${label} ${days} gün içinde sona eriyor. Gerekirse geçerli bir yenisini yükleyin.`,
      today: (label) => `${label} bugün sona eriyor. Lütfen geçerli bir yenisini yükleyin.`,
      expired: (label) => `${label} süresi doldu. Lütfen yenileme sürecini inceleyin.`,
    },
    fa: {
      title: "یادآوری انقضای مدرک پت‌تاکسی",
      days: (label, days) => `${label} تا ${days} روز دیگر منقضی می‌شود. در صورت نیاز جایگزین معتبر بارگذاری کنید.`,
      today: (label) => `${label} امروز منقضی می‌شود. لطفاً جایگزین معتبر بارگذاری کنید.`,
      expired: (label) => `${label} منقضی شده است. لطفاً روند جایگزینی را بررسی کنید.`,
    },
    ru: {
      title: "Напоминание об окончании документа Pet Taxi",
      days: (label, days) => `Срок действия документа «${label}» истекает через ${days} дн. При необходимости загрузите замену.`,
      today: (label) => `Срок действия документа «${label}» истекает сегодня. Загрузите замену.`,
      expired: (label) => `Срок действия документа «${label}» истёк. Проверьте процесс замены.`,
    },
  };
  const selected = copy[language] || copy.en;
  const label = (labels[documentKey] || labels.driverLicense)[language] ||
    (labels[documentKey] || labels.driverLicense).en;
  const body = daysUntilExpiry > 0
    ? selected.days(label, daysUntilExpiry)
    : daysUntilExpiry === 0
      ? selected.today(label)
      : selected.expired(label);
  return { title: selected.title, body };
}

function petTaxiDocumentVersionToken(document = {}) {
  const versionSource = String(document.storagePath || "legacy");
  return crypto.createHash("sha256").update(versionSource).digest("hex").slice(0, 32);
}

function petTaxiReminderDocId(
  businessId,
  documentKey,
  documentVersion,
  threshold,
  recipientId
) {
  return [
    "pet_taxi_expiry",
    businessId,
    documentKey,
    documentVersion,
    threshold,
    recipientId,
  ]
    .join("_")
    .replace(/[^A-Za-z0-9_-]/g, "_");
}

async function processPetTaxiExpiryReminders({ db, now = new Date(), sendPush = null }) {
  const businesses = await db.collection("businesses")
    .where("sectors", "array-contains", "pet_taxi")
    .get();
  const admins = await db.collection("users").where("role", "==", "admin").get();
  const adminUsers = admins.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
  let scanned = 0;
  let created = 0;

  for (const businessDoc of businesses.docs) {
    scanned += 1;
    const business = businessDoc.data() || {};
    const taxi = cloneMap(business.sectorData?.pet_taxi);
    const documents = cloneMap(taxi.documents);
    const ownerUid = String(business.ownerUid || "").trim();
    const ownerSnap = ownerUid ? await db.collection("users").doc(ownerUid).get() : null;
    const recipients = [];
    if (ownerUid) recipients.push({ id: ownerUid, data: ownerSnap?.data() || {} });
    recipients.push(...adminUsers);

    for (const documentKey of Object.keys(PET_TAXI_EXPIRY_FIELDS)) {
      const document = cloneMap(documents[documentKey]);
      const reminder = petTaxiExpiryReminderFor(documentKey, document, now);
      if (!reminder) continue;
      for (const recipient of recipients) {
        const locale = recipient.data.languageCode || recipient.data.locale || "en";
        const message = petTaxiExpiryReminderMessage(
          documentKey,
          reminder.daysUntilExpiry,
          locale
        );
        const threshold = reminder.daysUntilExpiry === -1
          ? "post_expiry"
          : String(reminder.daysUntilExpiry);
        const notificationRef = db.collection("notifications").doc(
          petTaxiReminderDocId(
            businessDoc.id,
            documentKey,
            petTaxiDocumentVersionToken(document),
            threshold,
            recipient.id
          )
        );
        try {
          await notificationRef.create({
            type: "pet_taxi_document_expiry",
            notificationType: "pet_taxi_document_expiry",
            recipientUserId: recipient.id,
            businessId: businessDoc.id,
            documentKey,
            reminderThreshold: threshold,
            daysUntilExpiry: reminder.daysUntilExpiry,
            title: message.title,
            body: message.body,
            senderUserId: "system",
            isRead: false,
            createdAt: new Date(),
          });
          created += 1;
        } catch (error) {
          const code = String(error?.code || "").toLowerCase();
          const message = String(error?.message || "").toLowerCase();
          if (code !== "already-exists" && code !== "6" && !message.includes("already exists")) {
            throw error;
          }
          continue;
        }
        const token = recipient.data.fcmToken;
        if (token && sendPush) {
          await sendPush({
            token,
            userId: recipient.id,
            title: message.title,
            body: message.body,
            data: {
              type: "pet_taxi_document_expiry",
              businessId: businessDoc.id,
              documentKey,
              reminderThreshold: threshold,
            },
          });
        }
      }
    }
  }
  return { scanned, created };
}

function petTaxiDataFromBusiness(businessData = {}) {
  const sectors = Array.isArray(businessData.sectors)
    ? businessData.sectors
    : [];
  if (!sectors.includes("pet_taxi")) {
    throw new HttpsError("failed-precondition", "Business is not Pet Taxi");
  }
  return cloneMap(businessData.sectorData?.pet_taxi);
}

function petTaxiAssessment(businessData = {}) {
  const taxi = petTaxiDataFromBusiness(businessData);
  const documents = cloneMap(taxi.documents);
  const compliance = cloneMap(taxi.compliance);
  const missingDocuments = REQUIRED_PET_TAXI_DOCUMENTS.filter((key) => {
    const document = cloneMap(documents[key]);
    return document.status !== "approved" ||
      document.verified !== true ||
      (!document.url && !document.storagePath);
  });
  const invalidExpiryDocuments = Object.keys(PET_TAXI_EXPIRY_FIELDS).filter(
    (key) => !evaluatePetTaxiDocumentExpiry(key, documents[key]).valid
  );
  const missingConditions = REQUIRED_PET_TAXI_COMPLIANCE_FLAGS.filter(
    (key) => compliance[key] !== true
  );
  return {
    taxi,
    documents,
    compliance,
    missingDocuments,
    invalidExpiryDocuments,
    missingConditions,
    documentsApproved:
      missingDocuments.length === 0 && invalidExpiryDocuments.length === 0,
    conditionsApproved: missingConditions.length === 0,
    complianceApproved:
      compliance.status === "approved" &&
      missingDocuments.length === 0 &&
      invalidExpiryDocuments.length === 0 &&
      missingConditions.length === 0,
  };
}

function sourceWithPetTaxi(businessData, taxi) {
  return {
    ...businessData,
    sectorData: {
      ...cloneMap(businessData.sectorData),
      pet_taxi: taxi,
    },
  };
}

function assertDocumentKey(documentKey) {
  if (!REQUIRED_PET_TAXI_DOCUMENTS.includes(documentKey)) {
    throw new HttpsError("invalid-argument", "Unsupported Pet Taxi document");
  }
}

function assertPetTaxiDocumentFormat(document) {
  const fileName = typeof document?.fileName === "string"
    ? document.fileName.trim()
    : "";
  const storagePath = typeof document?.storagePath === "string"
    ? document.storagePath.trim()
    : "";
  const contentType = typeof document?.contentType === "string"
    ? document.contentType.trim().toLowerCase()
    : "";
  const fileExtension = fileName.split(".").pop()?.toLowerCase();
  const storageExtension = storagePath.split(".").pop()?.toLowerCase();
  const expectedContentType = PET_TAXI_DOCUMENT_CONTENT_TYPES[fileExtension];
  if (
    !expectedContentType ||
    expectedContentType !== contentType ||
    PET_TAXI_DOCUMENT_CONTENT_TYPES[storageExtension] !== expectedContentType
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Pet Taxi documents must be PDF, JPG, JPEG, or PNG"
    );
  }
}

function assertBusinessId(businessId) {
  if (typeof businessId !== "string" || !businessId.trim()) {
    throw new HttpsError("invalid-argument", "Business id is required");
  }
}

function assertDocumentReviewTransition(document, action) {
  const status = document.status || "pending_review";
  if (status !== "pending_review") {
    throw new HttpsError("failed-precondition", "Illegal document state transition");
  }
}

async function updateRequestMirror(db, businessId, taxi, adminUid) {
  const snapshot = await db
    .collection("business_requests")
    .where("businessId", "==", businessId)
    .limit(1)
    .get();
  if (snapshot.empty) return;
  const requestRef = snapshot.docs[0].ref;
  await requestRef.set(
    {
      "sectorData.pet_taxi": taxi,
      petTaxiReviewUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      petTaxiReviewUpdatedBy: adminUid,
    },
    { merge: true }
  );
}

async function reviewPetTaxiDocument({ db, businessId, documentKey, action, reason, adminUid }) {
  assertBusinessId(businessId);
  assertDocumentKey(documentKey);
  if (!["approved", "rejected"].includes(action)) {
    throw new HttpsError("invalid-argument", "Invalid document action");
  }
  if (action === "rejected" && (!reason || !String(reason).trim())) {
    throw new HttpsError("invalid-argument", "Rejection reason is required");
  }

  const businessRef = db.collection("businesses").doc(businessId);
  let nextTaxi;
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(businessRef);
    if (!snapshot.exists) throw new HttpsError("not-found", "Business not found");
    const businessData = snapshot.data() || {};
    const taxi = petTaxiDataFromBusiness(businessData);
    const documents = cloneMap(taxi.documents);
    const current = cloneMap(documents[documentKey]);
    if (!current.url && !current.storagePath) {
      throw new HttpsError("failed-precondition", "Document has not been uploaded");
    }
    assertDocumentReviewTransition(current, action);
    if (action === "approved") {
      assertPetTaxiDocumentExpiryValid(documentKey, current);
    }

    const nextDocument = {
      ...current,
      status: action,
      verified: action === "approved",
      reviewedBy: adminUid,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectedReason: action === "rejected" ? String(reason).trim() : null,
      rejectionReason: action === "rejected" ? String(reason).trim() : null,
    };
    documents[documentKey] = nextDocument;
    nextTaxi = {
      ...taxi,
      documents,
      compliance: {
        ...cloneMap(taxi.compliance),
        status: action === "rejected" ? "pending_review" : cloneMap(taxi.compliance).status || "pending_review",
        manualReviewRequired: true,
        rejectionReason: action === "rejected" ? String(reason).trim() : null,
      },
      isActive: false,
      published: false,
    };
    const rootPatch = {
      "sectorData.pet_taxi": nextTaxi,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if ((Array.isArray(businessData.sectors) ? businessData.sectors : []).length === 1) {
      rootPatch.published = false;
    }
    tx.update(businessRef, {
      ...rootPatch,
    });
  });
  await updateRequestMirror(db, businessId, nextTaxi, adminUid);
  return { success: true, documentKey, status: action };
}

async function approvePetTaxiCompliance({ db, businessId, adminUid }) {
  assertBusinessId(businessId);
  const businessRef = db.collection("businesses").doc(businessId);
  let nextTaxi;
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(businessRef);
    if (!snapshot.exists) throw new HttpsError("not-found", "Business not found");
    const businessData = snapshot.data() || {};
    if (businessData.status !== "approved" || businessData.verification?.isVerified !== true) {
      throw new HttpsError("failed-precondition", "Root business approval is required");
    }
    const assessment = petTaxiAssessment(businessData);
    if (!assessment.documentsApproved || !assessment.conditionsApproved) {
      throw new HttpsError("failed-precondition", "Pet Taxi compliance requirements are incomplete");
    }
    const sectors = Array.isArray(businessData.sectors) ? businessData.sectors : [];
    // Activation is a separate administrative decision. Preserve it when the
    // current canonical lifecycle state is already fully active and published;
    // otherwise compliance approval must leave Pet Taxi inactive/unpublished.
    // The complete state is required because activation is only valid for a
    // single-sector Pet Taxi business.
    const preserveActivatedState =
      sectors.length === 1 &&
      sectors.includes("pet_taxi") &&
      businessData.published === true &&
      assessment.taxi.isActive === true &&
      assessment.taxi.published === true;
    nextTaxi = {
      ...assessment.taxi,
      compliance: {
        ...assessment.compliance,
        status: "approved",
        manualReviewRequired: false,
        reviewedBy: adminUid,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectionReason: null,
      },
      isActive: preserveActivatedState,
      published: preserveActivatedState,
    };
    const rootPatch = {
      "sectorData.pet_taxi": nextTaxi,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (sectors.length === 1) {
      rootPatch.published = preserveActivatedState;
    }
    tx.update(businessRef, {
      ...rootPatch,
    });
  });
  await updateRequestMirror(db, businessId, nextTaxi, adminUid);
  return { success: true, status: "approved" };
}

async function activatePetTaxiPublication({ db, businessId, adminUid }) {
  assertBusinessId(businessId);
  const businessRef = db.collection("businesses").doc(businessId);
  let nextTaxi;
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(businessRef);
    if (!snapshot.exists) throw new HttpsError("not-found", "Business not found");
    const businessData = snapshot.data() || {};
    if (businessData.status !== "approved") {
      throw new HttpsError("failed-precondition", "Root business must be approved");
    }
    if (businessData.verification?.isVerified !== true) {
      throw new HttpsError("failed-precondition", "Business verification is required");
    }
    const sectors = Array.isArray(businessData.sectors) ? businessData.sectors : [];
    if (sectors.length !== 1 || !sectors.includes("pet_taxi")) {
      throw new HttpsError(
        "failed-precondition",
        "Sector-specific Pet Taxi publication is unsafe for multi-sector businesses"
      );
    }
    const assessment = petTaxiAssessment(businessData);
    if (!assessment.complianceApproved) {
      throw new HttpsError("failed-precondition", "Pet Taxi compliance approval is required");
    }
    nextTaxi = {
      ...assessment.taxi,
      isActive: true,
      published: true,
      activatedBy: adminUid,
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    tx.update(businessRef, {
      "sectorData.pet_taxi": nextTaxi,
      published: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  await updateRequestMirror(db, businessId, nextTaxi, adminUid);
  return { success: true, active: true, published: true };
}

async function resubmitPetTaxiDocument({ db, businessId, documentKey, document, ownerUid }) {
  assertBusinessId(businessId);
  assertDocumentKey(documentKey);
  if (!document || typeof document !== "object" || !document.url || !document.storagePath) {
    throw new HttpsError("invalid-argument", "Uploaded document metadata is required");
  }
  assertPetTaxiDocumentFormat(document);
  const expectedPrefix = `business_sector_docs/${ownerUid}/pet_taxi/${documentKey}/`;
  if (!String(document.storagePath).startsWith(expectedPrefix)) {
    throw new HttpsError("permission-denied", "Document storage path is not owned by business");
  }
  const businessRef = db.collection("businesses").doc(businessId);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(businessRef);
    if (!snapshot.exists) throw new HttpsError("not-found", "Business not found");
    const businessData = snapshot.data() || {};
    if (businessData.ownerUid !== ownerUid) {
      throw new HttpsError("permission-denied", "Business owner only");
    }
    const taxi = petTaxiDataFromBusiness(businessData);
    const documents = cloneMap(taxi.documents);
    const current = cloneMap(documents[documentKey]);
    if (current.status !== "rejected") {
      throw new HttpsError(
        "failed-precondition",
        "Only rejected Pet Taxi documents can be resubmitted"
      );
    }
    if (PET_TAXI_EXPIRY_FIELDS[documentKey]) {
      assertPetTaxiDocumentExpiryValid(documentKey, document);
    }
    const nextDocument = {
      ...cloneMap(document),
      status: "pending_review",
      verified: false,
      rejectedReason: null,
      rejectionReason: null,
      uploadedBy: ownerUid,
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const canonicalExpiryField = PET_TAXI_EXPIRY_FIELDS[documentKey];
    delete nextDocument.expiryDate;
    delete nextDocument.driverLicenseExpiryDate;
    delete nextDocument.trafficInsuranceExpiryDate;
    if (canonicalExpiryField) {
      nextDocument[canonicalExpiryField] = expiryValueForDocument(documentKey, document);
    }
    documents[documentKey] = nextDocument;
    const nextTaxi = {
      ...taxi,
      documents,
      compliance: {
        ...cloneMap(taxi.compliance),
        status: "pending_review",
        manualReviewRequired: true,
        rejectionReason: null,
        approvedAt: null,
        reviewedAt: null,
        reviewedBy: null,
      },
      isActive: false,
      published: false,
    };
    const rootPatch = {
      "sectorData.pet_taxi": nextTaxi,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if ((Array.isArray(businessData.sectors) ? businessData.sectors : []).length === 1) {
      rootPatch.published = false;
    }
    tx.update(businessRef, {
      ...rootPatch,
    });
  });
  return { success: true, status: "pending_review" };
}

module.exports = {
  REQUIRED_PET_TAXI_DOCUMENTS,
  REQUIRED_PET_TAXI_COMPLIANCE_FLAGS,
  petTaxiAssessment,
  PET_TAXI_EXPIRY_FIELDS,
  PET_TAXI_EXPIRY_REMINDER_DAYS,
  expiryValueForDocument,
  parseExpiryDate,
  evaluatePetTaxiDocumentExpiry,
  assertPetTaxiDocumentExpiryValid,
  expiryCalendarDate,
  petTaxiExpiryReminderFor,
  petTaxiExpiryReminderMessage,
  petTaxiDocumentVersionToken,
  petTaxiReminderDocId,
  processPetTaxiExpiryReminders,
  reviewPetTaxiDocument,
  approvePetTaxiCompliance,
  activatePetTaxiPublication,
  resubmitPetTaxiDocument,
};
