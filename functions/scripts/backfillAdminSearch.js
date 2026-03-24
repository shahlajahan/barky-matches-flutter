const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

function normalize(text) {
    return String(text || "")
        .toLowerCase()
        .trim()
        .replace(/[^\p{L}\p{N}\s]/gu, " ");
}

function tokenize(text) {
    return Array.from(
        new Set(
            normalize(text)
                .split(/\s+/)
                .filter((t) => t.length > 0)
        )
    );
}

function generatePrefixes(tokens) {
    const prefixes = new Set();

    for (const token of tokens) {
        for (let i = 1; i <= token.length; i++) {
            prefixes.add(token.substring(0, i));
        }
    }

    return Array.from(prefixes);
}

function buildSearchDoc({
    entityType,
    entityId,
    title,
    subtitle,
    status = null,
    badge = null,
    photoUrl = null,
    keywords = [],
    extra = {},
    createdAt = null,
    updatedAt = null,
}) {
    const text = [title, subtitle, ...keywords].join(" ");
    const tokens = tokenize(text);
    const prefixes = generatePrefixes(tokens);

    return {
        entityType,
        entityId,
        title: title || "",
        subtitle: subtitle || "",
        status,
        badge,
        photoUrl,
        searchTerms: tokens,
        searchPrefixes: prefixes,
        extra,
        createdAt: createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: updatedAt || admin.firestore.FieldValue.serverTimestamp(),
    };
}

async function upsertIndexDoc(id, data) {
    await db.collection("admin_search_index").doc(id).set(data, { merge: true });
}

async function backfillUsers() {
    console.log("🔹 Backfilling users...");
    const snap = await db.collection("users").get();
    let count = 0;

    for (const doc of snap.docs) {
        const u = doc.data();
        const userId = doc.id;

        const searchDoc = buildSearchDoc({
            entityType: "user",
            entityId: userId,
            title: u.username || u.displayName || "User",
            subtitle: [u.email || "", u.phone || ""].filter(Boolean).join(" • "),
            status: u.status || "active",
            badge: u.role === "admin" ? "admin" : (u.isVerified ? "verified" : null),
            photoUrl: u.photoUrl || u.profileImageUrl || null,
            keywords: [
                u.username,
                u.displayName,
                u.email,
                u.phone,
                u.role,
                u.city,
                u.country,
            ],
            extra: {
                role: u.role || "user",
                city: u.city || null,
                country: u.country || null,
            },
            createdAt: u.createdAt || null,
            updatedAt: u.updatedAt || null,
        });

        await upsertIndexDoc(`user_${userId}`, searchDoc);
        count++;
    }

    console.log(`✅ Users indexed: ${count}`);
}

async function backfillDogs() {
    console.log("🔹 Backfilling dogs...");
    const snap = await db.collection("dogs").get();
    let count = 0;

    for (const doc of snap.docs) {
        const d = doc.data();
        const dogId = doc.id;

        const title = d.name || "Dog";
        const subtitle = [d.breed || "", d.ownerUsername || ""]
            .filter(Boolean)
            .join(" • ");

        const searchDoc = buildSearchDoc({
            entityType: "dog",
            entityId: dogId,
            title,
            subtitle,
            status: d.moderation?.effectiveStatus || (d.isAvailableForAdoption ? "adoption" : "active"),
            badge: d.isLost
                ? "lost"
                : d.isFound
                    ? "found"
                    : d.isAdopted
                        ? "adopted"
                        : null,
            photoUrl: d.imageUrl || d.photoUrl || null,
            keywords: [
                d.name,
                d.breed,
                d.gender,
                d.ownerUsername,
                d.ownerUid,
                d.ownerId,
                d.city,
                d.district,
            ],
            extra: {
                ownerUid: d.ownerUid || d.ownerId || null,
                ownerUsername: d.ownerUsername || null,
                city: d.city || null,
                district: d.district || null,
            },
            createdAt: d.createdAt || null,
            updatedAt: d.updatedAt || null,
        });

        await upsertIndexDoc(`dog_${dogId}`, searchDoc);
        count++;
    }

    console.log(`✅ Dogs indexed: ${count}`);
}

async function backfillBusinesses() {
    console.log("🔹 Backfilling businesses...");
    const snap = await db.collection("businesses").get();
    let count = 0;

    for (const doc of snap.docs) {
        const b = doc.data();
        const businessId = doc.id;

        const displayName =
            b.profile?.displayName ||
            b.name ||
            "Business";

        const city = b.contact?.city || b.city || "";
        const district = b.contact?.district || b.district || "";
        const type = b.type || "";

        const subtitle = [city, district, type].filter(Boolean).join(" • ");

        const searchDoc = buildSearchDoc({
            entityType: "business",
            entityId: businessId,
            title: displayName,
            subtitle,
            status: b.status || "pending",
            badge:
                b.verification?.isVerified || b.isVerified
                    ? "verified"
                    : null,
            photoUrl: b.profile?.logoUrl || b.logoUrl || null,
            keywords: [
                displayName,
                city,
                district,
                type,
                b.contact?.phone,
                b.contact?.whatsapp,
                b.contact?.email,
                b.contact?.instagram,
                b.contact?.website,
                b.ownerUid,
            ],
            extra: {
                ownerUid: b.ownerUid || null,
                city: city || null,
                district: district || null,
                type: type || null,
            },
            createdAt: b.createdAt || null,
            updatedAt: b.updatedAt || null,
        });

        await upsertIndexDoc(`business_${businessId}`, searchDoc);
        count++;
    }

    console.log(`✅ Businesses indexed: ${count}`);
}

async function backfillReports() {
    console.log("🔹 Backfilling reports...");
    const snap = await db.collection("reports").get();
    let count = 0;

    for (const doc of snap.docs) {
        const r = doc.data();
        const reportId = doc.id;

        const title = `Report ${reportId}`;
        const subtitle = [r.type || "", r.reasonText || r.reasonCode || ""]
            .filter(Boolean)
            .join(" • ");

        const searchDoc = buildSearchDoc({
            entityType: "report",
            entityId: reportId,
            title,
            subtitle,
            status: r.status || "pending",
            badge: r.source || null,
            photoUrl: null,
            keywords: [
                reportId,
                r.type,
                r.targetId,
                r.targetOwnerId,
                r.reasonCode,
                r.reasonText,
                r.reportedBy,
                r.source,
            ],
            extra: {
                targetId: r.targetId || null,
                targetOwnerId: r.targetOwnerId || null,
                reporterId: r.reportedBy || null,
                type: r.type || null,
            },
            createdAt: r.createdAt || null,
            updatedAt: r.updatedAt || null,
        });

        await upsertIndexDoc(`report_${reportId}`, searchDoc);
        count++;
    }

    console.log(`✅ Reports indexed: ${count}`);
}

async function backfillComplaints() {
    console.log("🔹 Backfilling complaints...");
    const snap = await db.collection("complaints").get();
    let count = 0;

    for (const doc of snap.docs) {
        const c = doc.data();
        const complaintId = doc.id;

        const title = c.title || `Complaint ${complaintId}`;
        const subtitle = [c.category || "", c.targetType || "", c.severity || ""]
            .filter(Boolean)
            .join(" • ");

        const searchDoc = buildSearchDoc({
            entityType: "complaint",
            entityId: complaintId,
            title,
            subtitle,
            status: c.status || "open",
            badge: c.priority || null,
            photoUrl: null,
            keywords: [
                complaintId,
                c.category,
                c.targetType,
                c.targetId,
                c.severity,
                c.priority,
                c.createdBy,
                c.description,
            ],
            extra: {
                targetId: c.targetId || null,
                targetType: c.targetType || null,
                createdBy: c.createdBy || null,
            },
            createdAt: c.createdAt || null,
            updatedAt: c.updatedAt || null,
        });

        await upsertIndexDoc(`complaint_${complaintId}`, searchDoc);
        count++;
    }

    console.log(`✅ Complaints indexed: ${count}`);
}

async function run() {
    console.log("🚀 Starting admin_search_index backfill...");

    await backfillUsers();
    await backfillDogs();
    await backfillBusinesses();
    await backfillReports();
    await backfillComplaints();

    console.log("🎉 Backfill complete.");
}

run()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error("❌ Backfill failed:", err);
        process.exit(1);
    });