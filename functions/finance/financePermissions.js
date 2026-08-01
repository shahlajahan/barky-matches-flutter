"use strict";

const { HttpsError } = require("firebase-functions/v2/https");

const FINANCE_PERMISSION = Object.freeze({
  VIEW: "finance.view",
  OPERATE: "finance.operate",
  APPROVE: "finance.approve",
  MANAGE: "finance.manage",
});

const ROLE_PERMISSIONS = Object.freeze({
  finance_viewer: new Set([FINANCE_PERMISSION.VIEW]),
  finance_operator: new Set([
    FINANCE_PERMISSION.VIEW,
    FINANCE_PERMISSION.OPERATE,
  ]),
  finance_manager: new Set(Object.values(FINANCE_PERMISSION)),
  admin: new Set([FINANCE_PERMISSION.VIEW]),
  super_admin: new Set(Object.values(FINANCE_PERMISSION)),
});

function permissionsForUser(user, claims = {}) {
  const role = String(user?.role || claims?.role || "").trim().toLowerCase();
  const permissions = new Set(ROLE_PERMISSIONS[role] || []);
  for (const permission of user?.financePermissions || []) {
    permissions.add(String(permission));
  }
  for (const permission of claims?.financePermissions || []) {
    permissions.add(String(permission));
  }
  return permissions;
}

function isAdminRole(role, claims = {}) {
  const normalizedRole = String(role || "").trim().toLowerCase();
  return (
    normalizedRole === "admin" ||
    normalizedRole === "super_admin" ||
    claims?.admin === true ||
    claims?.isAdmin === true
  );
}

async function resolveFinanceAuthorization(db, request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required.");
  }
  const userSnap = await db.collection("users").doc(request.auth.uid).get();
  const user = userSnap.exists ? userSnap.data() || {} : {};
  const claims = request.auth.token || {};
  const role = String(user.role || claims.role || "");
  const isAdmin = isAdminRole(role, claims);
  const permissions = permissionsForUser(user, claims);
  return {
    uid: request.auth.uid,
    role,
    isAdmin,
    hasFinanceView: permissions.has(FINANCE_PERMISSION.VIEW),
    hasFinanceOperate: permissions.has(FINANCE_PERMISSION.OPERATE),
    hasFinanceApprove: permissions.has(FINANCE_PERMISSION.APPROVE),
    hasFinanceManage: permissions.has(FINANCE_PERMISSION.MANAGE),
    permissions: [...permissions],
    userExists: userSnap.exists,
  };
}

function logFinanceAuthorization({ authorization, requiredPermission, request, decision, denialReason, report }) {
  console.info("[FinanceAuth] authorization decision", {
    uid: authorization?.uid || request.auth?.uid || null,
    resolvedRole: authorization?.role || null,
    isAdmin: authorization?.isAdmin === true,
    hasFinanceView: authorization?.hasFinanceView === true,
    hasFinanceOperate: authorization?.hasFinanceOperate === true,
    requiredPermission: requiredPermission || null,
    requestedReportId: report?.reportId || request.data?.reportId || null,
    reportFullIban: report?.fullIban ?? null,
    generatedBy: report?.generatedBy || null,
    decision,
    denialReason: denialReason || null,
  });
}

async function requireFinancePermission(db, request, requiredPermission, context = {}) {
  const authorization = await resolveFinanceAuthorization(db, request);
  const allowed = authorization.permissions.includes(requiredPermission);
  if (!allowed) {
    logFinanceAuthorization({
      authorization,
      requiredPermission,
      request,
      report: context.report,
      decision: "deny",
      denialReason: authorization.userExists
        ? "missing_effective_permission"
        : "user_document_missing",
    });
    throw new HttpsError(
      "permission-denied",
      "Your Finance permissions could not be resolved.",
      {
        code: "FINANCE_AUTHORIZATION_UNRESOLVED",
        reason: authorization.userExists
          ? "missing_effective_permission"
          : "user_document_missing",
      }
    );
  }
  logFinanceAuthorization({
    authorization,
    requiredPermission,
    request,
    report: context.report,
    decision: "allow",
  });
  return {
    ...authorization,
    permission: requiredPermission,
  };
}

module.exports = {
  FINANCE_PERMISSION,
  ROLE_PERMISSIONS,
  permissionsForUser,
  isAdminRole,
  resolveFinanceAuthorization,
  logFinanceAuthorization,
  requireFinancePermission,
};
