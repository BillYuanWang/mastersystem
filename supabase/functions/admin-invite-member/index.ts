import { withSupabase } from "npm:@supabase/server@1.4.0";

const allowedRoles = ["administrator", "guardian", "adult_student"] as const;
type AppRole = (typeof allowedRoles)[number];

type ProfileRow = {
  user_id: string;
  organization_id: string;
  role: AppRole;
  display_name: string;
  appearance: "system" | "light" | "dark";
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

type Database = {
  public: {
    Tables: {
      profiles: {
        Row: ProfileRow;
        Insert: Partial<ProfileRow>;
        Update: Partial<ProfileRow>;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      admin_finalize_invited_member: {
        Args: {
          target_user_id: string;
          target_email: string;
          target_display_name: string;
          target_role: AppRole;
          target_student_ids: string[];
        };
        Returns: ProfileRow;
      };
    };
    Enums: {
      app_role: AppRole;
    };
    CompositeTypes: Record<string, never>;
  };
};

type InviteBody = {
  email?: unknown;
  displayName?: unknown;
  role?: unknown;
  studentIds?: unknown;
};

function jsonError(message: string, status: number): Response {
  return Response.json({ error: message }, { status });
}

function isAppRole(value: string): value is AppRole {
  return (allowedRoles as readonly string[]).includes(value);
}

export default {
  fetch: withSupabase<Database>({ auth: "user" }, async (request, context) => {
    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    let body: InviteBody;
    try {
      body = await request.json();
    } catch {
      return jsonError("A JSON body is required", 400);
    }

    const email = typeof body.email === "string"
      ? body.email.trim().toLowerCase()
      : "";
    const displayName = typeof body.displayName === "string"
      ? body.displayName.trim()
      : "";
    const role = typeof body.role === "string" ? body.role : "";
    const studentIds = Array.isArray(body.studentIds)
      ? [
        ...new Set(body.studentIds.filter((value): value is string =>
          typeof value === "string"
        )),
      ]
      : [];

    if (!/^\S+@\S+\.\S+$/.test(email)) {
      return jsonError("A valid email is required", 400);
    }
    if (displayName.length < 1 || displayName.length > 120) {
      return jsonError("Display name must contain 1 to 120 characters", 400);
    }
    if (!isAppRole(role)) {
      return jsonError("Unsupported account role", 400);
    }
    if (role === "adult_student" && studentIds.length !== 1) {
      return jsonError("Adult-student invitations require one student", 400);
    }
    if (role === "administrator" && studentIds.length !== 0) {
      return jsonError(
        "Administrator invitations cannot include students",
        400,
      );
    }

    const callerId = context.userClaims?.id;
    if (!callerId) {
      return jsonError("Authentication required", 401);
    }

    const { data: callerProfile, error: callerError } = await context.supabase
      .from("profiles")
      .select("organization_id, role, is_active")
      .eq("user_id", callerId)
      .maybeSingle();

    if (
      callerError || callerProfile?.role !== "administrator" ||
      !callerProfile.is_active
    ) {
      return jsonError("Administrator access required", 403);
    }

    const redirectTo = role === "administrator"
      ? "masterdance-desk://auth-callback"
      : "masterdance://auth-callback";
    const { data: invitation, error: invitationError } = await context
      .supabaseAdmin.auth.admin.inviteUserByEmail(email, {
        redirectTo,
        data: {
          display_name: displayName,
          invited_role: role,
        },
      });

    if (invitationError || !invitation.user) {
      return jsonError(invitationError?.message ?? "Invitation failed", 409);
    }

    const targetUserId = invitation.user.id;
    const { data: profile, error: profileError } = await context.supabase.rpc(
      "admin_finalize_invited_member",
      {
        target_user_id: targetUserId,
        target_email: email,
        target_display_name: displayName,
        target_role: role,
        target_student_ids: studentIds,
      },
    );

    if (profileError) {
      const { error: cleanupError } = await context.supabaseAdmin.auth.admin
        .deleteUser(targetUserId);
      if (cleanupError) {
        console.error("invite cleanup failed", { targetUserId });
      }
      return jsonError(profileError.message, 422);
    }

    return Response.json({ profile }, { status: 201 });
  }),
};
