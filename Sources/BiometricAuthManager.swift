import LocalAuthentication

struct BiometricAuthManager {

    enum AuthResult {
        case success
        case failed(String)
        case cancelled
        case unavailable
    }

    static func authenticate(reason: String, completion: @escaping (AuthResult) -> Void) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.unavailable)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
            DispatchQueue.main.async {
                if success {
                    completion(.success)
                    return
                }
                if let err = evalError as? LAError,
                   err.code == .userCancel || err.code == .appCancel {
                    completion(.cancelled)
                    return
                }
                completion(.failed(evalError?.localizedDescription ?? "Authentication failed"))
            }
        }
    }

    static var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}
