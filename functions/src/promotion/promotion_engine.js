"use strict";

const crypto = require("crypto");
const admin = require("firebase-admin");

const {
  COLLECTIONS,
  PRICING_MODELS,
  TARGET_TYPES,
  validatePromotionPlan,
} = require("./promotion_contract");

const dbTimestamp = (value) => {
  if (value && typeof value.toMillis === "function") return value;
  if (value instanceof Date) return admin.firestore.Timestamp.fromDate(value);
  return admin.firestore.Timestamp.fromMillis(Number(value));
};

const asNonEmptyString = (value, field) => {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${field} is required`);
  }
  return value.trim();
};

const normalizeServiceSector = (value) => {
  const normalized = String(value || "").trim().toLowerCase();
  if (["vet", "veterinary", "veterinarian"].includes(normalized)) return "VET";
  if (["groom", "groomer", "groomy", "grooming"].includes(normalized)) return "GROOMER";
  if (["hotel", "pet_hotel", "pethotel", "boarding"].includes(normalized)) return "PET_HOTEL";
  if (["taxi", "pet_taxi", "pettaxi"].includes(normalized)) return "PET_TAXI";
  return null;
};

const canonicalServiceTargetId = (sector, businessId, serviceId) => {
  const normalizedSector = normalizeServiceSector(sector);
  if (!normalizedSector) throw new Error("SERVICE sector is required");
  const business = asNonEmptyString(businessId, "businessId");
  const service = asNonEmptyString(serviceId, "serviceId");
  if (business.includes("/") || service.includes("/")) {
    throw new Error("SERVICE target identity contains an invalid path segment");
  }
  return `service/${normalizedSector}/${business}/${service}`;
};

const parseCanonicalServiceTargetId = (targetId) => {
  const value = asNonEmptyString(targetId, "targetId");
  const parts = value.split("/");
  if (parts.length !== 4 || parts[0] !== "service" || !parts[1] || !parts[2] || !parts[3]) {
    return null;
  }
  return {sector: normalizeServiceSector(parts[1]), businessId: parts[2], serviceId: parts[3]};
};

const normalizeCurrency = (value) => String(value || "").trim().toUpperCase();

const stableCampaignId = (uid, idempotencyKey) => {
  const digest = crypto
    .createHash("sha256")
    .update(`${uid}|${idempotencyKey}`)
    .digest("hex");
  return `promotion_${digest.slice(0, 40)}`;
};

const safeFailureCode = (value) => {
  const normalized = String(value || "promotion_failed")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, "_")
    .slice(0, 80);
  return normalized || "promotion_failed";
};

function assertPromotionRequest(data = {}) {
  const targetType = asNonEmptyString(data.targetType, "targetType").toUpperCase();
  const targetId = asNonEmptyString(data.targetId, "targetId");
  const planId = asNonEmptyString(data.planId, "planId");
  const idempotencyKey = asNonEmptyString(data.idempotencyKey, "idempotencyKey");

  if (!TARGET_TYPES.includes(targetType)) {
    throw new Error(`Unsupported promotion target type: ${targetType}`);
  }
  if (idempotencyKey.length > 128) {
    throw new Error("idempotencyKey is too long");
  }
  if (data.sector && !normalizeServiceSector(data.sector)) {
    throw new Error("Unsupported service sector");
  }
  return {
    targetType,
    targetId,
    planId,
    idempotencyKey,
    businessId: data.businessId ? String(data.businessId).trim() : null,
    serviceSector: data.sector ? normalizeServiceSector(data.sector) : null,
  };
}

function isPublicBusiness(data = {}) {
  if (data.status !== undefined && data.status !== "approved") return false;
  if (data.published !== undefined && data.published !== true) return false;
  if (data.isActive !== undefined && data.isActive !== true) return false;
  if (data.isSuspended === true || data.suspended === true) return false;
  return true;
}

function businessOwnerUid(data = {}) {
  const ownerUid = data.ownerUid || data.uid || data.ownerId || null;
  return ownerUid ? String(ownerUid) : null;
}

function assertTargetOwner(target, uid) {
  if (!target || target.ownerUid !== uid) {
    throw new Error("Promotion target is not owned by caller");
  }
}

const TERMINAL_ACTIVATION_ELIGIBILITY_PATTERNS = [
  /target not found/i,
  /target is not eligible/i,
  /business is not eligible/i,
  /ownership mismatch/i,
  /not owned by caller/i,
  /target owner not found/i,
  /sector does not match/i,
  /sector is not enabled/i,
];

function isTerminalActivationEligibilityError(error) {
  return TERMINAL_ACTIVATION_ELIGIBILITY_PATTERNS.some((pattern) =>
    pattern.test(String(error?.message || ""))
  );
}

async function resolvePromotionTarget({db, uid, targetType, targetId, businessId, serviceSector}) {
  const normalizedType = asNonEmptyString(targetType, "targetType").toUpperCase();
  const normalizedId = asNonEmptyString(targetId, "targetId");

  if (normalizedType === "BUSINESS") {
    throw new Error("BUSINESS promotions are disabled in V1");
  }

  if (normalizedType === "PET") {
    const snap = await db.collection("dogs").doc(normalizedId).get();
    if (!snap.exists) throw new Error("Pet target not found");
    const data = snap.data() || {};
    const ownerUid = data.ownerId || data.ownerUid || null;
    if (!ownerUid || data.isActive === false || data.isHidden === true || data.moderationStatus === "removed") {
      throw new Error("Pet target is not eligible for promotion");
    }
    const target = {
      targetType: "PET",
      targetId: normalizedId,
      ownerUid: String(ownerUid),
      businessId: null,
      sector: "pet",
    };
    assertTargetOwner(target, uid);
    return target;
  }

  if (normalizedType !== "PRODUCT" && normalizedType !== "SERVICE") {
    throw new Error(`Unsupported promotion target type: ${normalizedType}`);
  }
  const canonicalService = normalizedType === "SERVICE"
    ? parseCanonicalServiceTargetId(normalizedId)
    : null;
  if (normalizedType === "SERVICE" && (!canonicalService || !canonicalService.sector)) {
    throw new Error("SERVICE targetId must be a canonical service identity");
  }
  if (canonicalService && businessId && canonicalService.businessId !== String(businessId).trim()) {
    throw new Error("SERVICE target business does not match targetId");
  }
  const normalizedBusinessId = asNonEmptyString(
    canonicalService?.businessId || businessId,
    "businessId",
  );
  const serviceId = canonicalService?.serviceId || normalizedId;
  const businessRef = db.collection("businesses").doc(normalizedBusinessId);
  const businessSnap = await businessRef.get();
  if (!businessSnap.exists) throw new Error("Business target owner not found");
  const business = businessSnap.data() || {};
  const ownerUid = businessOwnerUid(business);
  if (!ownerUid || !isPublicBusiness(business)) {
    throw new Error("Business is not eligible for promotion");
  }

  const childCollection = normalizedType === "PRODUCT" ? "products" : "services";
  const childSnap = await businessRef.collection(childCollection).doc(serviceId).get();
  if (!childSnap.exists) throw new Error(`${normalizedType} target not found`);
  const child = childSnap.data() || {};
  if (child.isActive !== true || child.isHidden === true || child.moderationStatus === "removed") {
    throw new Error(`${normalizedType} target is not eligible for promotion`);
  }
  if (normalizedType === "PRODUCT") {
    if (child.productId && String(child.productId) !== normalizedId) {
      throw new Error("PRODUCT target identity mismatch");
    }
    if (typeof child.stock !== "number" || !Number.isFinite(child.stock) || child.stock <= 0) {
      throw new Error("PRODUCT target is not available for promotion");
    }
  }
  if (child.businessId && String(child.businessId) !== normalizedBusinessId) {
    throw new Error(`${normalizedType} business ownership mismatch`);
  }

  let resolvedSector = null;
  if (normalizedType === "SERVICE") {
    const sectorData = business.sectorData && typeof business.sectorData === "object"
      ? Object.keys(business.sectorData)
      : [];
    const businessSector = normalizeServiceSector(
      business.serviceSector || business.sector || business.businessType || business.sectors?.[0] || sectorData[0],
    );
    if (businessSector && canonicalService.sector !== businessSector) {
      throw new Error("SERVICE target sector does not match business");
    }
    if (serviceSector && businessSector && serviceSector !== businessSector) {
      throw new Error("SERVICE sector does not match business");
    }
    resolvedSector = businessSector || canonicalService.sector || serviceSector;
    if (resolvedSector && !["VET", "GROOMER"].includes(resolvedSector)) {
      throw new Error("SERVICE sector is not enabled for Promotion");
    }
  }

  const target = {
    targetType: normalizedType,
    targetId: normalizedType === "SERVICE"
      ? normalizedId
      : normalizedId,
    ownerUid,
    businessId: normalizedBusinessId,
    sector: resolvedSector || (Array.isArray(business.sectors) ? String(business.sectors[0] || "") : null),
    // Trusted snapshots used only to build backend-owned public projections.
    // They are never returned to clients or persisted on the campaign.
    businessData: business,
    childData: child,
  };
  assertTargetOwner(target, uid);
  return target;
}

async function resolvePromotionPlan({db, planId, targetType}) {
  const normalizedPlanId = asNonEmptyString(planId, "planId");
  const snap = await db.collection(COLLECTIONS.plans).doc(normalizedPlanId).get();
  if (!snap.exists) throw new Error("Promotion plan not found");
  const plan = snap.data() || {};
  validatePromotionPlan(plan, normalizedPlanId);
  if (String(plan.targetType).toUpperCase() !== String(targetType).toUpperCase()) {
    throw new Error("Promotion plan target type does not match target");
  }
  if (plan.pricingModel !== PRICING_MODELS.fixedDuration) {
    throw new Error("Only FIXED_DURATION promotion plans are enabled in V1");
  }
  if (plan.targetType === "BUSINESS" || plan.enabled !== true) {
    throw new Error("Promotion plan is disabled");
  }
  if (normalizeCurrency(plan.currency) !== "TRY") {
    throw new Error("Promotion currency is not supported");
  }
  return {planId: normalizedPlanId, ...plan};
}

function campaignResponse(data, campaignId) {
  return {
    campaignId,
    targetType: data.targetType,
    targetId: data.targetId,
    businessId: data.businessId || null,
    campaignStatus: data.status,
    paymentStatus: data.paymentStatus || "pending",
    provider: data.paymentProvider || null,
    checkoutUrl: data.checkoutUrl || null,
    checkoutHtml: data.checkoutHtml || null,
    checkoutToken: data.checkoutToken || null,
    gatewayUrl: data.gatewayUrl || null,
    storeType: data.storeType || null,
    hashAlgorithm: data.hashAlgorithm || null,
    providerOrderId: data.providerOrderId || null,
  };
}

function publicCheckoutFields(providerResult = {}) {
  return {
    checkoutUrl: providerResult.checkoutUrl || null,
    checkoutHtml: providerResult.html || null,
    gatewayUrl: providerResult.gatewayUrl || null,
    storeType: providerResult.storeType || null,
    hashAlgorithm: providerResult.hashAlgorithm || null,
    checkoutToken: providerResult.token || null,
  };
}

async function createPromotionCheckoutCore({
  db,
  uid,
  data,
  now = new Date(),
  createProviderCheckout,
  authEmail = null,
  clientIp = null,
}) {
  const callerUid = asNonEmptyString(uid, "uid");
  const request = assertPromotionRequest(data);
  const target = await resolvePromotionTarget({db, uid: callerUid, ...request});
  const plan = await resolvePromotionPlan({
    db,
    planId: request.planId,
    targetType: request.targetType,
  });
  const userSnap = await db.collection("users").doc(callerUid).get();
  const userData = userSnap.exists ? userSnap.data() || {} : {};
  if (plan.targetType === "BUSINESS") throw new Error("BUSINESS promotions are disabled in V1");

  const campaignId = stableCampaignId(callerUid, request.idempotencyKey);
  const campaignRef = db.collection(COLLECTIONS.campaigns).doc(campaignId);
  const createdAt = dbTimestamp(now);
  const reservationExpiresAt = admin.firestore.Timestamp.fromMillis(
    createdAt.toMillis() + 2 * 60 * 1000
  );

  const reservation = await db.runTransaction(async (tx) => {
    const existingSnap = await tx.get(campaignRef);
    if (existingSnap.exists) {
      const existing = existingSnap.data() || {};
      if (existing.ownerUid !== callerUid) throw new Error("Promotion campaign ownership mismatch");
      if (existing.status === "active") return {kind: "existing", data: existing};
      if (["expired", "cancelled", "failed", "refunded"].includes(existing.status)) {
        throw new Error("Idempotency key belongs to a terminal campaign");
      }
      if (existing.checkoutUrl || existing.checkoutHtml) return {kind: "existing", data: existing};
      if (existing.checkoutLeaseExpiresAt && existing.checkoutLeaseExpiresAt.toMillis() > createdAt.toMillis()) {
        return {kind: "in_progress", data: existing};
      }
    }

    if (["PRODUCT", "SERVICE"].includes(request.targetType)) {
      const activeProjectionSnap = await tx.get(
        db.collection(COLLECTIONS.active)
          .where("targetType", "==", request.targetType)
      );
      const hasActivePromotion = activeProjectionSnap.docs.some((doc) => {
        const projection = doc.data() || {};
        const expiresAt = projection.expiresAt;
        return projection.targetType === request.targetType &&
          projection.targetId === target.targetId &&
          expiresAt &&
          typeof expiresAt.toMillis === "function" &&
          expiresAt.toMillis() > createdAt.toMillis();
      });
      if (hasActivePromotion) {
        throw new Error(`${request.targetType} target already has an active promotion`);
      }
    }

    const dataToWrite = {
      campaignId,
      ownerUid: callerUid,
      targetType: target.targetType,
      targetId: target.targetId,
      businessId: target.businessId,
      sector: target.sector,
      pricingModel: plan.pricingModel,
      planId: plan.planId,
      pricingVersion: plan.pricingVersion,
      durationHours: plan.durationHours,
      currency: normalizeCurrency(plan.currency),
      price: Number(plan.price),
      rankingWeight: Number(plan.rankingLift),
      status: "pending_payment",
      paymentStatus: "pending",
      paymentAttemptId: campaignId,
      paymentProvider: null,
      providerOrderId: campaignId,
      idempotencyKey: request.idempotencyKey,
      checkoutLeaseExpiresAt: reservationExpiresAt,
      createdAt,
      updatedAt: createdAt,
      version: 1,
    };
    tx.set(campaignRef, dataToWrite, {merge: true});
    return {kind: "reserved", data: dataToWrite};
  });

  if (reservation.kind === "existing") return campaignResponse(reservation.data, campaignId);
  if (reservation.kind === "in_progress") {
    return {campaignId, campaignStatus: "pending_payment", paymentStatus: "pending", retryable: true};
  }
  if (typeof createProviderCheckout !== "function") throw new Error("Promotion provider adapter is required");

  let providerResult;
  try {
    providerResult = await createProviderCheckout({
      campaign: reservation.data,
      plan,
      target,
      userData,
      authEmail,
      clientIp,
    });
  } catch (error) {
    await failPromotionPayment({
      db,
      campaignId,
      failureCode: "checkout_creation_failed",
      now,
    });
    throw error;
  }
  if (!providerResult || !providerResult.provider) throw new Error("Promotion provider checkout failed");

  const checkoutFields = publicCheckoutFields(providerResult);
  const update = {
    paymentProvider: String(providerResult.provider).toLowerCase(),
    providerOrderId: providerResult.providerOrderId || campaignId,
    paymentStatus: "pending",
    checkoutToken: providerResult.token || null,
    checkoutUrl: checkoutFields.checkoutUrl,
    checkoutHtml: checkoutFields.checkoutHtml,
    gatewayUrl: checkoutFields.gatewayUrl,
    storeType: checkoutFields.storeType,
    hashAlgorithm: checkoutFields.hashAlgorithm,
    checkoutCreatedAt: dbTimestamp(now),
    checkoutLeaseExpiresAt: null,
    updatedAt: dbTimestamp(now),
  };
  await db.runTransaction(async (tx) => {
    const latestSnap = await tx.get(campaignRef);
    if (!latestSnap.exists) throw new Error("Promotion campaign disappeared");
    const latest = latestSnap.data() || {};
    if (latest.status === "active") return;
    if (latest.paymentProvider && latest.checkoutUrl) return;
    tx.update(campaignRef, update);
  });

  const finalSnap = await campaignRef.get();
  return campaignResponse(finalSnap.data() || update, campaignId);
}

function normalizeVerifiedPayment(evidence = {}) {
  return {
    verified: evidence.verified === true,
    provider: String(evidence.provider || "").trim().toLowerCase(),
    providerOrderId: String(evidence.providerOrderId || "").trim(),
    providerTransactionId: String(evidence.providerTransactionId || "").trim(),
    amount: Number(evidence.amount),
    currency: normalizeCurrency(evidence.currency),
    paymentStatus: String(evidence.paymentStatus || "").trim().toLowerCase(),
  };
}

async function activatePromotionFromVerifiedPayment({db, campaignId, evidence, now = new Date()}) {
  const normalizedCampaignId = asNonEmptyString(campaignId, "campaignId");
  const payment = normalizeVerifiedPayment(evidence);
  if (!payment.verified) throw new Error("Promotion payment is not verified");
  if (!payment.provider || !payment.providerOrderId || !payment.providerTransactionId) {
    throw new Error("Promotion payment evidence is incomplete");
  }
  if (!Number.isFinite(payment.amount) || payment.amount < 0) throw new Error("Promotion payment amount is invalid");

  const ref = db.collection(COLLECTIONS.campaigns).doc(normalizedCampaignId);
  const projectionRef = db.collection(COLLECTIONS.active).doc(normalizedCampaignId);
  const activationTime = dbTimestamp(now);
  let result = "activated";

  // Revalidate the domain target immediately before activation. Checkout
  // eligibility is not sufficient because ownership, publication, stock, or
  // service availability can change while the provider flow is open.
  const beforeActivationSnap = await ref.get();
  if (!beforeActivationSnap.exists) throw new Error("Promotion campaign not found");
  const beforeActivation = beforeActivationSnap.data() || {};
  const alreadyProcessed = beforeActivation.status === "active" &&
    beforeActivation.providerTransactionId === payment.providerTransactionId;
  let activationTarget = null;
  if (!alreadyProcessed) {
    try {
      activationTarget = await resolvePromotionTarget({
        db,
        uid: beforeActivation.ownerUid,
        targetType: beforeActivation.targetType,
        targetId: beforeActivation.targetId,
        businessId: beforeActivation.businessId,
        serviceSector: beforeActivation.sector,
      });
    } catch (error) {
      if (isTerminalActivationEligibilityError(error)) {
        await failPromotionPayment({
          db,
          campaignId: normalizedCampaignId,
          failureCode: "target_ineligible_after_payment",
          now,
        });
        throw new Error("Promotion target became ineligible before activation");
      }
      throw error;
    }
  }

  await db.runTransaction(async (tx) => {
    const campaignSnap = await tx.get(ref);
    if (!campaignSnap.exists) throw new Error("Promotion campaign not found");
    const campaign = campaignSnap.data() || {};

    if (campaign.status === "active") {
      const sameTransaction = campaign.providerTransactionId === payment.providerTransactionId;
      if (sameTransaction) {
        result = "already_processed";
        return;
      }
      throw new Error("Active promotion has a conflicting payment transaction");
    }
    if (!["pending_payment", "payment_processing"].includes(campaign.status)) {
      throw new Error(`Promotion campaign cannot activate from ${campaign.status}`);
    }
    if (campaign.paymentProvider !== payment.provider) {
      throw new Error("Promotion payment provider mismatch");
    }
    if (campaign.providerOrderId !== payment.providerOrderId) {
      throw new Error("Promotion provider order mismatch");
    }
    if (normalizeCurrency(campaign.currency) !== payment.currency) {
      throw new Error("Promotion payment currency mismatch");
    }
    if (Math.abs(Number(campaign.price) - payment.amount) > 0.005) {
      throw new Error("Promotion payment amount mismatch");
    }

    const startsAt = activationTime;
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      startsAt.toMillis() + Number(campaign.durationHours) * 60 * 60 * 1000
    );
    const campaignUpdate = {
      status: "active",
      paymentStatus: "paid",
      providerTransactionId: payment.providerTransactionId,
      paidAt: activationTime,
      verifiedAt: activationTime,
      activatedAt: activationTime,
      startsAt,
      expiresAt,
      updatedAt: activationTime,
      version: Number(campaign.version || 1) + 1,
      activationSource: "verified_provider_payment",
    };
    const projection = {
      campaignId: normalizedCampaignId,
      targetType: campaign.targetType,
      targetId: campaign.targetId,
      ownerUid: campaign.ownerUid,
      businessId: campaign.businessId || null,
      sector: campaign.sector || null,
      featuredDealEligible: campaign.targetType === "SERVICE"
        ? Boolean(activationTarget)
        : false,
      startsAt,
      expiresAt,
      rankingWeight: Number(campaign.rankingWeight || 0),
      placementPolicy: "bounded_v1",
      publicLabel: "Promoted",
      campaignVersion: campaignUpdate.version,
      updatedAt: activationTime,
    };
    if (campaign.targetType === "SERVICE" && activationTarget) {
      const businessData = activationTarget.businessData || {};
      const service = activationTarget.childData || {};
      const profile = businessData.profile && typeof businessData.profile === "object"
        ? businessData.profile
        : {};
      const contact = businessData.contact && typeof businessData.contact === "object"
        ? businessData.contact
        : {};
      projection.businessName = String(
        profile.displayName || profile.businessName || businessData.businessName || businessData.name || "Business"
      );
      projection.serviceTitle = String(service.title || service.name || service.serviceName || "Service");
      projection.location = [contact.district, contact.city]
        .map((value) => String(value || "").trim())
        .filter(Boolean)
        .join(", ");
      projection.price = service.price ?? null;
      projection.currency = service.currency || "TRY";
      projection.logoUrl = profile.logoUrl || profile.coverUrl || businessData.logoUrl || businessData.coverImageUrl || null;
      projection.serviceId = parseCanonicalServiceTargetId(campaign.targetId)?.serviceId || null;
    }
    tx.update(ref, campaignUpdate);
    tx.set(projectionRef, projection);
  });

  const snap = await ref.get();
  return {status: result, campaignId: normalizedCampaignId, campaign: snap.data() || {}};
}

async function failPromotionPayment({db, campaignId, failureCode, now = new Date()}) {
  const ref = db.collection(COLLECTIONS.campaigns).doc(asNonEmptyString(campaignId, "campaignId"));
  const timestamp = dbTimestamp(now);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error("Promotion campaign not found");
    const current = snap.data() || {};
    if (["active", "expired", "cancelled", "refunded"].includes(current.status)) return;
    tx.update(ref, {
      status: "failed",
      paymentStatus: "failed",
      failureCode: safeFailureCode(failureCode),
      updatedAt: timestamp,
      version: Number(current.version || 1) + 1,
    });
  });
  return {campaignId: ref.id, status: "failed"};
}

async function readPromotionPaymentStatus({db, uid, campaignId}) {
  const ref = db.collection(COLLECTIONS.campaigns).doc(asNonEmptyString(campaignId, "campaignId"));
  const snap = await ref.get();
  if (!snap.exists) throw new Error("Promotion campaign not found");
  const data = snap.data() || {};
  if (data.ownerUid !== asNonEmptyString(uid, "uid")) throw new Error("Not authorized to read promotion campaign");
  return {
    campaignId: ref.id,
    targetType: data.targetType,
    targetId: data.targetId,
    campaignStatus: data.status,
    paymentStatus: data.paymentStatus || null,
    startsAt: data.startsAt || null,
    expiresAt: data.expiresAt || null,
  };
}

module.exports = {
  assertPromotionRequest,
  canonicalServiceTargetId,
  parseCanonicalServiceTargetId,
  resolvePromotionTarget,
  resolvePromotionPlan,
  createPromotionCheckoutCore,
  activatePromotionFromVerifiedPayment,
  failPromotionPayment,
  readPromotionPaymentStatus,
  stableCampaignId,
};
