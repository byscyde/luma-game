// LUMA sign-in for iOS (GDExtension), used by scripts/cloud/native_auth.gd as the
// "LumaAuth" singleton. Apple: AuthenticationServices (Sign in with Apple).
// Google and Facebook: the system sign-in sheet (ASWebAuthenticationSession), the same
// mechanism the Google and Facebook SDKs use, with PKCE for Google.
// Every attempt ends with the signal sign_in_completed(provider, token, error).
#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class LumaAuth : public Object {
	GDCLASS(LumaAuth, Object);

	String google_client_id;   // iOS OAuth client id
	String facebook_app_id;
	void *delegate = nullptr;  // LumaAuthDelegate (Objective-C, retained)

protected:
	static void _bind_methods();

public:
	LumaAuth();
	~LumaAuth();

	void configure(const String &json);
	bool is_available(const String &provider) const;
	void sign_in(const String &provider, const String &nonce);
	void sign_out(const String &provider);

	// Called from Objective-C on the main thread.
	void finish(const String &provider, const String &token, const String &error);
};

} // namespace godot
