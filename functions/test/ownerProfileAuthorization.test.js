"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const editOwnerProfilePage = fs.readFileSync(
  path.resolve(
    __dirname,
    "../../lib/ui/business/dashboard/vet/patients/edit_owner_profile_page.dart"
  ),
  "utf8"
);
const medicalRecordsPage = fs.readFileSync(
  path.resolve(__dirname, "../../lib/ui/medical_records/medical_records_page.dart"),
  "utf8"
);
const vetPatientDetailPage = fs.readFileSync(
  path.resolve(
    __dirname,
    "../../lib/ui/business/dashboard/vet/patients/vet_patient_detail_page.dart"
  ),
  "utf8"
);
const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

test("Medical Records routes owner-owned dogs into EditOwnerProfilePage", () => {
  assert.match(medicalRecordsPage, /collection\('dogs'\)/);
  assert.match(medicalRecordsPage, /\.where\('ownerId', isEqualTo: userId\)/);
  assert.match(medicalRecordsPage, /businessId:\s*'owner_medical_record'/);
  assert.match(vetPatientDetailPage, /EditOwnerProfilePage\(/);
});

test("EditOwnerProfilePage writes only approved owner profile fields", () => {
  assert.match(editOwnerProfilePage, /buildEditableOwnerProfile\(/);
  assert.match(editOwnerProfilePage, /'ownerProfile\.\$\{entry\.key\}': entry\.value/);
  assert.doesNotMatch(editOwnerProfilePage, /updatedOwnerProfile\['email'\]/);
  assert.doesNotMatch(editOwnerProfilePage, /'ownerProfile': updatedOwnerProfile/);
  assert.doesNotMatch(editOwnerProfilePage, /'ownerProfile': editableOwnerProfile/);
});

test("owner medical save does not mirror into business patients", () => {
  const ownerMode = editOwnerProfilePage.match(
    /if \(_isOwnerMedicalMode\) \{([\s\S]*?)\n        Navigator\.pop\(context\);/
  )?.[1] || "";
  assert.match(ownerMode, /collection\('dogs'\)/);
  assert.match(ownerMode, /collection\('users'\)/);
  assert.doesNotMatch(ownerMode, /collectionGroup\('patients'\)/);
  assert.doesNotMatch(ownerMode, /collection\('businesses'\)/);
});

test("dog rules allow only owner profile snapshot fields for dog owners", () => {
  const dogs = rules.match(/match \/dogs\/\{dogId\} \{([\s\S]*?)\n    \}/)?.[1] || "";
  assert.match(dogs, /isDogOwner\(resource\.data\) &&\s*isOwnerProfileSnapshotUpdate\(\)/);
  assert.match(rules, /function ownerProfileEditableFields\(\)/);
  for (const field of [
    "ownerName",
    "ownerPhone",
    "emergencyContact",
    "emergencyPhone",
    "city",
    "district",
    "address",
  ]) {
    assert.match(rules, new RegExp(`'${field}'`));
  }
  assert.match(rules, /'ownerProfileUpdatedAt'/);
  assert.match(rules, /'updatedAt'/);
  assert.doesNotMatch(dogs, /allow update:\s*if isSignedIn\(\)/);
});

test("user rules deny normal users from changing protected account fields", () => {
  assert.match(rules, /function protectedUserFields\(\)/);
  for (const field of [
    "uid",
    "userId",
    "ownerUid",
    "ownerId",
    "role",
    "admin",
    "isAdmin",
    "isPremium",
    "subscription",
    "subscriptions",
    "entitlement",
    "entitlements",
    "businessId",
    "businessOwnerUid",
    "creator",
  ]) {
    assert.match(rules, new RegExp(`'${field}'`));
  }
  assert.match(rules, /selfUserUpdateFieldsAreAllowed\(\)/);
  assert.match(rules, /affectedKeys\(\)\s*\.hasAny\(protectedUserFields\(\)\)/);
});
