#include "luma_auth.h"

#include <gdextension_interface.h>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#import <AuthenticationServices/AuthenticationServices.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

using namespace godot;

static NSString *to_ns(const String &s) {
	return [NSString stringWithUTF8String:s.utf8().get_data()];
}

static String to_gd(NSString *s) {
	return s ? String::utf8([s UTF8String]) : String();
}

static NSString *random_hex(int bytes) {
	NSMutableData *d = [NSMutableData dataWithLength:bytes];
	(void)SecRandomCopyBytes(kSecRandomDefault, bytes, d.mutableBytes);
	NSMutableString *out = [NSMutableString string];
	const unsigned char *p = (const unsigned char *)d.bytes;
	for (int i = 0; i < bytes; i++) [out appendFormat:@"%02x", p[i]];
	return out;
}

static NSData *sha256(NSString *s) {
	NSData *in = [s dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableData *out = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
	CC_SHA256(in.bytes, (CC_LONG)in.length, (unsigned char *)out.mutableBytes);
	return out;
}

static NSString *sha256_hex(NSString *s) {
	NSData *h = sha256(s);
	NSMutableString *out = [NSMutableString string];
	const unsigned char *p = (const unsigned char *)h.bytes;
	for (NSUInteger i = 0; i < h.length; i++) [out appendFormat:@"%02x", p[i]];
	return out;
}

static NSString *base64url(NSData *d) {
	NSString *b = [d base64EncodedStringWithOptions:0];
	b = [b stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
	b = [b stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	return [b stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

static UIWindow *key_window() {
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:UIWindowScene.class]) continue;
		for (UIWindow *w in ((UIWindowScene *)scene).windows) {
			if (w.isKeyWindow) return w;
		}
	}
	return UIApplication.sharedApplication.windows.firstObject;
}

// Query or fragment parameters of a callback URL.
static NSDictionary<NSString *, NSString *> *url_params(NSURL *url) {
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	NSURLComponents *c = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
	for (NSURLQueryItem *q in c.queryItems) if (q.value) out[q.name] = q.value;
	if (c.fragment.length) {
		NSURLComponents *f = [NSURLComponents new];
		f.percentEncodedQuery = c.fragment;
		for (NSURLQueryItem *q in f.queryItems) if (q.value) out[q.name] = q.value;
	}
	return out;
}

@interface LumaAuthDelegate : NSObject <ASAuthorizationControllerDelegate,
		ASAuthorizationControllerPresentationContextProviding,
		ASWebAuthenticationPresentationContextProviding>
@property(nonatomic, assign) LumaAuth *owner;
@property(nonatomic, strong) ASWebAuthenticationSession *session;
@property(nonatomic, strong) ASAuthorizationController *controller;
@end

@implementation LumaAuthDelegate

- (void)finish:(NSString *)provider token:(NSString *)token error:(NSString *)error {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.owner) self.owner->finish(to_gd(provider), to_gd(token ?: @""), to_gd(error ?: @""));
	});
}

// MARK: Apple

- (void)signInApple:(NSString *)nonce {
	ASAuthorizationAppleIDRequest *req = [[ASAuthorizationAppleIDProvider new] createRequest];
	req.requestedScopes = @[];      // no name, no e-mail: the server keeps only the user id
	req.nonce = sha256_hex(nonce);  // the server compares sha256(raw nonce)
	self.controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ req ]];
	self.controller.delegate = self;
	self.controller.presentationContextProvider = self;
	[self.controller performRequests];
}

- (void)authorizationController:(ASAuthorizationController *)c didCompleteWithAuthorization:(ASAuthorization *)a {
	ASAuthorizationAppleIDCredential *cred = (ASAuthorizationAppleIDCredential *)a.credential;
	NSString *token = cred.identityToken ? [[NSString alloc] initWithData:cred.identityToken encoding:NSUTF8StringEncoding] : nil;
	[self finish:@"apple" token:token error:token ? nil : @"no identity token"];
}

- (void)authorizationController:(ASAuthorizationController *)c didCompleteWithError:(NSError *)e {
	[self finish:@"apple" token:nil error:(e.code == ASAuthorizationErrorCanceled ? @"cancelled" : e.localizedDescription)];
}

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)c {
	return key_window();
}

// MARK: Google (authorization code + PKCE, iOS client: no secret)

- (void)signInGoogle:(NSString *)clientId nonce:(NSString *)nonce {
	NSArray *parts = [clientId componentsSeparatedByString:@"."];
	NSString *scheme = [[[parts reverseObjectEnumerator] allObjects] componentsJoinedByString:@"."];
	NSString *redirect = [scheme stringByAppendingString:@":/oauth2redirect"];
	NSString *verifier = random_hex(32);
	NSString *state = random_hex(16);
	NSURLComponents *u = [NSURLComponents componentsWithString:@"https://accounts.google.com/o/oauth2/v2/auth"];
	u.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"client_id" value:clientId],
		[NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirect],
		[NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
		[NSURLQueryItem queryItemWithName:@"scope" value:@"openid"],
		[NSURLQueryItem queryItemWithName:@"code_challenge" value:base64url(sha256(verifier))],
		[NSURLQueryItem queryItemWithName:@"code_challenge_method" value:@"S256"],
		[NSURLQueryItem queryItemWithName:@"nonce" value:nonce],
		[NSURLQueryItem queryItemWithName:@"state" value:state],
	];
	__weak LumaAuthDelegate *weakSelf = self;
	self.session = [[ASWebAuthenticationSession alloc] initWithURL:u.URL callbackURLScheme:scheme
			completionHandler:^(NSURL *callback, NSError *error) {
				LumaAuthDelegate *me = weakSelf;
				if (!me) return;
				if (error || !callback) {
					[me finish:@"google" token:nil error:(error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin ? @"cancelled" : @"failed")];
					return;
				}
				NSDictionary *p = url_params(callback);
				if (![p[@"state"] isEqualToString:state] || !p[@"code"]) {
					[me finish:@"google" token:nil error:@"bad redirect"];
					return;
				}
				[me exchangeGoogleCode:p[@"code"] clientId:clientId redirect:redirect verifier:verifier];
			}];
	self.session.presentationContextProvider = self;
	[self.session start];
}

- (void)exchangeGoogleCode:(NSString *)code clientId:(NSString *)clientId redirect:(NSString *)redirect verifier:(NSString *)verifier {
	NSURLComponents *body = [NSURLComponents new];
	body.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"code" value:code],
		[NSURLQueryItem queryItemWithName:@"client_id" value:clientId],
		[NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirect],
		[NSURLQueryItem queryItemWithName:@"code_verifier" value:verifier],
		[NSURLQueryItem queryItemWithName:@"grant_type" value:@"authorization_code"],
	];
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://oauth2.googleapis.com/token"]];
	req.HTTPMethod = @"POST";
	[req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	req.HTTPBody = [body.percentEncodedQuery dataUsingEncoding:NSUTF8StringEncoding];
	[[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
		NSDictionary *j = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
		NSString *idToken = [j isKindOfClass:NSDictionary.class] ? j[@"id_token"] : nil;
		[self finish:@"google" token:idToken error:idToken ? nil : @"token exchange failed"];
	}] resume];
}

// MARK: Facebook (login dialog, access token back to fb<app id>://authorize/)

- (void)signInFacebook:(NSString *)appId {
	NSString *scheme = [@"fb" stringByAppendingString:appId];
	NSString *state = random_hex(16);
	NSURLComponents *u = [NSURLComponents componentsWithString:@"https://www.facebook.com/v19.0/dialog/oauth"];
	u.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"client_id" value:appId],
		[NSURLQueryItem queryItemWithName:@"redirect_uri" value:[scheme stringByAppendingString:@"://authorize/"]],
		[NSURLQueryItem queryItemWithName:@"response_type" value:@"token"],
		[NSURLQueryItem queryItemWithName:@"scope" value:@"public_profile"],
		[NSURLQueryItem queryItemWithName:@"state" value:state],
	];
	__weak LumaAuthDelegate *weakSelf = self;
	self.session = [[ASWebAuthenticationSession alloc] initWithURL:u.URL callbackURLScheme:scheme
			completionHandler:^(NSURL *callback, NSError *error) {
				LumaAuthDelegate *me = weakSelf;
				if (!me) return;
				if (error || !callback) {
					[me finish:@"facebook" token:nil error:(error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin ? @"cancelled" : @"failed")];
					return;
				}
				NSDictionary *p = url_params(callback);
				NSString *token = p[@"access_token"];
				if (p[@"error"] || ![p[@"state"] isEqualToString:state] || !token) {
					[me finish:@"facebook" token:nil error:p[@"error"] ?: @"bad redirect"];
					return;
				}
				[me finish:@"facebook" token:token error:nil];
			}];
	self.session.presentationContextProvider = self;
	[self.session start];
}

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)s {
	return key_window();
}

@end

// MARK: - Godot side

void LumaAuth::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "json"), &LumaAuth::configure);
	ClassDB::bind_method(D_METHOD("is_available", "provider"), &LumaAuth::is_available);
	ClassDB::bind_method(D_METHOD("sign_in", "provider", "nonce"), &LumaAuth::sign_in);
	ClassDB::bind_method(D_METHOD("sign_out", "provider"), &LumaAuth::sign_out);
	ADD_SIGNAL(MethodInfo("sign_in_completed", PropertyInfo(Variant::STRING, "provider"),
			PropertyInfo(Variant::STRING, "token"), PropertyInfo(Variant::STRING, "error")));
}

LumaAuth::LumaAuth() {
	LumaAuthDelegate *d = [LumaAuthDelegate new];
	d.owner = this;
	delegate = (__bridge_retained void *)d;
}

LumaAuth::~LumaAuth() {
	LumaAuthDelegate *d = (__bridge_transfer LumaAuthDelegate *)delegate;
	d.owner = nullptr;
	delegate = nullptr;
}

void LumaAuth::configure(const String &json) {
	Variant v = JSON::parse_string(json);
	if (v.get_type() != Variant::DICTIONARY) return;
	Dictionary d = v;
	google_client_id = d.get("google_ios_client_id", "");
	facebook_app_id = d.get("facebook_app_id", "");
}

bool LumaAuth::is_available(const String &provider) const {
	if (provider == "apple") return true;
	if (provider == "google") return !google_client_id.is_empty();
	if (provider == "facebook") return !facebook_app_id.is_empty();
	return false;
}

void LumaAuth::sign_in(const String &provider, const String &nonce) {
	LumaAuthDelegate *d = (__bridge LumaAuthDelegate *)delegate;
	NSString *n = to_ns(nonce);
	if (provider == "apple") {
		[d signInApple:n];
	} else if (provider == "google" && !google_client_id.is_empty()) {
		[d signInGoogle:to_ns(google_client_id) nonce:n];
	} else if (provider == "facebook" && !facebook_app_id.is_empty()) {
		[d signInFacebook:to_ns(facebook_app_id)];
	} else {
		finish(provider, "", "unsupported");
	}
}

void LumaAuth::sign_out(const String &provider) {
	// Nothing is kept on the device: the next sign-in shows the provider's sheet again.
}

void LumaAuth::finish(const String &provider, const String &token, const String &error) {
	call_deferred("emit_signal", "sign_in_completed", provider, token, error);
}

// MARK: - Registration (in this Objective-C++ file so -ObjC / -u keep it in the static link)


static LumaAuth *singleton = nullptr;

static void initialize(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	GDREGISTER_CLASS(LumaAuth);
	singleton = memnew(LumaAuth);
	Engine::get_singleton()->register_singleton("LumaAuth", singleton);
}

static void uninitialize(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	Engine::get_singleton()->unregister_singleton("LumaAuth");
	memdelete(singleton);
	singleton = nullptr;
}

extern "C" {
GDExtensionBool GDE_EXPORT luma_auth_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		const GDExtensionClassLibraryPtr library, GDExtensionInitialization *init) {
	GDExtensionBinding::InitObject obj(get_proc_address, library, init);
	obj.register_initializer(initialize);
	obj.register_terminator(uninitialize);
	obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return obj.init();
}
}
