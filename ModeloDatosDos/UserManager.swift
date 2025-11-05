import Foundation
import FirebaseFirestore
import FirebaseAuth

struct User {
    let userId: String?
    let name: String
    let email: String
    let username: String
    let password: String
    let phone: String?
    let registrationDate: Date
    let imageProfile: String? // Campo para imagen en base64
    
    init(name: String, email: String, username: String, password: String, phone: String? = nil, registrationDate: Date = Date(), userId: String? = nil, imageProfile: String? = nil) {
        self.userId = userId
        self.name = name
        self.email = email
        self.username = username
        self.password = password
        self.phone = phone
        self.registrationDate = registrationDate
        self.imageProfile = imageProfile
    }
    
    init?(from dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String,
              let email = dictionary["email"] as? String,
              let username = dictionary["username"] as? String,
              let password = dictionary["password"] as? String,
              let registrationTimestamp = dictionary["registrationDate"] as? TimeInterval else {
            return nil
        }
        
        self.userId = dictionary["userId"] as? String
        self.name = name
        self.email = email
        self.username = username
        self.password = password
        self.phone = dictionary["phone"] as? String
        self.registrationDate = Date(timeIntervalSince1970: registrationTimestamp)
        self.imageProfile = dictionary["imageProfile"] as? String
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "email": email.lowercased(),
            "username": username.lowercased(),
            "password": password,
            "registrationDate": registrationDate.timeIntervalSince1970
        ]
        
        if let userId = userId {
            dict["userId"] = userId
        }
        
        if let phone = phone {
            dict["phone"] = phone
        }
        
        if let imageProfile = imageProfile {
            dict["imageProfile"] = imageProfile
        }
        
        return dict
    }
}

class UserManager {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let currentUserKey = "CurrentUser"
    
    private init() {}
    
    // MARK: - Firebase Auth Methods
    
    func registerUserWithAuth(_ user: User, completion: @escaping (Bool, String?) -> Void) {
        // Primero crear usuario en Firebase Auth
        Auth.auth().createUser(withEmail: user.email, password: user.password) { [weak self] authResult, error in
            if let error = error {
                let errorMessage = self?.getFirebaseAuthErrorMessage(error) ?? error.localizedDescription
                completion(false, errorMessage)
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                completion(false, "Error al obtener datos del usuario creado")
                return
            }
            
            // Enviar email de verificación
            firebaseUser.sendEmailVerification { error in
                if let error = error {
                    print("Error enviando email de verificación: \(error.localizedDescription)")
                    // No fallar el registro por esto, solo informar
                }
            }
            
            // Crear el usuario en Firestore con el UID de Firebase Auth
            var userData = user.toDictionary()
            userData["userId"] = firebaseUser.uid
            
            self?.db.collection(self?.usersCollection ?? "users").document(firebaseUser.uid).setData(userData) { error in
                if let error = error {
                    print("Error guardando usuario en Firestore: \(error.localizedDescription)")
                    completion(false, "Error al guardar datos del usuario")
                } else {
                    completion(true, nil)
                }
            }
        }
    }
    
    func signInWithAuth(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                let errorMessage = UserManager.shared.getFirebaseAuthErrorMessage(error)
                completion(false, errorMessage)
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                completion(false, "Error al obtener datos del usuario")
                return
            }
            
            // Verificar si el email está verificado
            if !firebaseUser.isEmailVerified {
                completion(false, "Debes verificar tu email antes de iniciar sesión. Revisa tu bandeja de entrada.")
                return
            }
            
            // Login exitoso y email verificado
            completion(true, nil)
        }
    }
    
    func resendVerificationEmail(completion: @escaping (Bool, String?) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(false, "No hay usuario logueado")
            return
        }
        
        currentUser.sendEmailVerification { error in
            if let error = error {
                print("Error reenviando email de verificación: \(error.localizedDescription)")
                completion(false, "Error al enviar email de verificación")
            } else {
                completion(true, nil)
            }
        }
    }
    
    func checkEmailVerificationStatus(completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        currentUser.reload { error in
            if let error = error {
                print("Error actualizando estado del usuario: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(currentUser.isEmailVerified)
            }
        }
    }
    
    func getCurrentFirebaseUser() -> FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            logout() // Limpiar también UserDefaults
        } catch {
            print("Error al cerrar sesión: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling Helper
    
    private func getFirebaseAuthErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        let errorCode = nsError.code
        
        switch errorCode {
        case 17007: // FIRAuthErrorCodeEmailAlreadyInUse
            return "Este correo electrónico ya está en uso"
        case 17008: // FIRAuthErrorCodeInvalidEmail
            return "El correo electrónico no es válido"
        case 17026: // FIRAuthErrorCodeWeakPassword
            return "La contraseña es muy débil. Usa al menos 6 caracteres"
        case 17011: // FIRAuthErrorCodeUserNotFound
            return "No se encontró una cuenta con este correo"
        case 17009: // FIRAuthErrorCodeWrongPassword
            return "Contraseña incorrecta"
        case 17020: // FIRAuthErrorCodeNetworkError
            return "Error de conexión. Verifica tu internet"
        case 17999: // FIRAuthErrorCodeInternalError
            return "Error interno de Firebase. Verifica la configuración del proyecto y las reglas de autenticación"
        case 17010: // FIRAuthErrorCodeUserDisabled
            return "Esta cuenta ha sido deshabilitada"
        case 17012: // FIRAuthErrorCodeOperationNotAllowed
            return "⚠️ El método de autenticación Email/Password está deshabilitado.\n\nPara solucionarlo:\n1. Ve a Firebase Console\n2. Authentication → Sign-in method\n3. Habilita 'Email/Password'\n4. Guarda los cambios"
        default:
            // Buscar mensaje específico en la descripción
            let description = error.localizedDescription.lowercased()
            if description.contains("sign-in provider is disabled") {
                return "⚠️ El método de autenticación Email/Password está deshabilitado.\n\nPara solucionarlo:\n1. Ve a Firebase Console\n2. Authentication → Sign-in method\n3. Habilita 'Email/Password'\n4. Guarda los cambios"
            }
            return "Error de autenticación (código \(errorCode)): \(error.localizedDescription)"
        }
    }
    
    // MARK: - Public Methods
    
    func registerUser(_ user: User, completion: @escaping (Bool, String?) -> Void) {
        // Primero verificar si el usuario ya existe
        isUsernameAvailable(user.username) { [weak self] isAvailable in
            guard isAvailable else {
                completion(false, "El nombre de usuario ya está en uso")
                return
            }
            
            // Verificar si el email ya está en uso
            self?.isEmailAvailable(user.email) { isEmailAvailable in
                guard isEmailAvailable else {
                    completion(false, "El correo electrónico ya está en uso")
                    return
                }
                
                // Generar un ID único para el documento
                let userRef = self?.db.collection(self?.usersCollection ?? "users").document()
                let userId = userRef?.documentID ?? UUID().uuidString
                
                // Agregar el ID único a los datos del usuario
                var userData = user.toDictionary()
                userData["userId"] = userId
                
                // Registrar el usuario con ID único
                userRef?.setData(userData) { error in
                    if let error = error {
                        print("Error al registrar usuario: \(error.localizedDescription)")
                        completion(false, "Error al registrar usuario: \(error.localizedDescription)")
                    } else {
                        print("Usuario registrado exitosamente con ID: \(userId)")
                        completion(true, nil)
                    }
                }
            }
        }
    }
    
    func isUsernameAvailable(_ username: String, completion: @escaping (Bool) -> Void) {
        let lowercaseUsername = username.lowercased()
        
        db.collection(usersCollection)
            .whereField("username", isEqualTo: lowercaseUsername)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error verificando username: \(error.localizedDescription)")
                    // En caso de error de permisos, asumir que está disponible para no bloquear el registro
                    if error.localizedDescription.contains("permissions") {
                        print("⚠️ Error de permisos en Firestore. Verifica las reglas de seguridad.")
                        completion(true) // Permitir el registro cuando hay errores de permisos
                    } else {
                        completion(false) // Para otros errores, asumir no disponible
                    }
                    return
                }
                
                // Si no hay documentos, el username está disponible
                completion(querySnapshot?.documents.isEmpty ?? true)
            }
    }
    
    func isEmailAvailable(_ email: String, completion: @escaping (Bool) -> Void) {
        db.collection(usersCollection)
            .whereField("email", isEqualTo: email.lowercased())
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error verificando email: \(error.localizedDescription)")
                    // En caso de error de permisos, asumir que está disponible
                    if error.localizedDescription.contains("permissions") {
                        print("⚠️ Error de permisos en Firestore. Verifica las reglas de seguridad.")
                        completion(true) // Permitir el registro cuando hay errores de permisos
                    } else {
                        completion(false) // Para otros errores, asumir no disponible
                    }
                    return
                }
                
                completion(querySnapshot?.documents.isEmpty ?? true)
            }
    }
    
    func validateCredentials(username: String, password: String, completion: @escaping (Bool) -> Void) {
        let lowercaseUsername = username.lowercased()
        
        db.collection(usersCollection)
            .whereField("username", isEqualTo: lowercaseUsername)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error validando credenciales: \(error.localizedDescription)")
                    if error.localizedDescription.contains("permissions") {
                        print("⚠️ Error de permisos en Firestore. Verifica las reglas de seguridad.")
                    }
                    completion(false)
                    return
                }
                
                guard let documents = querySnapshot?.documents, !documents.isEmpty,
                      let data = documents.first?.data(),
                      let storedPassword = data["password"] as? String else {
                    completion(false)
                    return
                }
                
                completion(storedPassword == password)
            }
    }
    
    func validateCredentialsByEmail(email: String, password: String, completion: @escaping (Bool) -> Void) {
        let lowercaseEmail = email.lowercased()
        
        db.collection(usersCollection)
            .whereField("email", isEqualTo: lowercaseEmail)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error validando credenciales por email: \(error.localizedDescription)")
                    if error.localizedDescription.contains("permissions") {
                        print("⚠️ Error de permisos en Firestore. Verifica las reglas de seguridad.")
                    }
                    completion(false)
                    return
                }
                
                guard let documents = querySnapshot?.documents, !documents.isEmpty,
                      let data = documents.first?.data(),
                      let storedPassword = data["password"] as? String else {
                    completion(false)
                    return
                }
                
                completion(storedPassword == password)
            }
    }
    
    func getUser(by username: String, completion: @escaping (User?) -> Void) {
        let lowercaseUsername = username.lowercased()
        
        db.collection(usersCollection)
            .whereField("username", isEqualTo: lowercaseUsername)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error obteniendo usuario: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let documents = querySnapshot?.documents, !documents.isEmpty,
                      let data = documents.first?.data() else {
                    completion(nil)
                    return
                }
                
            completion(User(from: data))
        }
    }
    
    func getUser(by email: String, byEmail: Bool, completion: @escaping (User?) -> Void) {
        let lowercaseEmail = email.lowercased()
        
        db.collection(usersCollection)
            .whereField("email", isEqualTo: lowercaseEmail)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error obteniendo usuario por email: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let documents = querySnapshot?.documents, !documents.isEmpty,
                      let data = documents.first?.data() else {
                    completion(nil)
                    return
                }
                
                completion(User(from: data))
            }
    }
    
    func getAllRegisteredUsers(completion: @escaping ([User]) -> Void) {
        db.collection(usersCollection).getDocuments { querySnapshot, error in
            if let error = error {
                print("Error obteniendo todos los usuarios: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let users = querySnapshot?.documents.compactMap { document in
                User(from: document.data())
            } ?? []
            
            completion(users)
        }
    }
    
    // MARK: - Current User Management (aún usa UserDefaults para el usuario actual)
    
    func setCurrentUser(_ username: String) {
        UserDefaults.standard.set(username.lowercased(), forKey: currentUserKey)
        UserDefaults.standard.synchronize()
    }
    
    func setCurrentUserByEmail(_ email: String) {
        UserDefaults.standard.set(email.lowercased(), forKey: "currentUserEmail")
        UserDefaults.standard.synchronize()
    }
    
    func getCurrentUser(completion: @escaping (User?) -> Void) {
        // Primero verificar si hay un usuario logueado por email
        if let currentEmail = UserDefaults.standard.string(forKey: "currentUserEmail") {
            getUser(by: currentEmail, byEmail: true, completion: completion)
            return
        }
        
        // Si no hay email, verificar por username (retrocompatibilidad)
        guard let currentUsername = getCurrentUsername() else {
            completion(nil)
            return
        }
        
        getUser(by: currentUsername, completion: completion)
    }
    
    func getCurrentUsername() -> String? {
        return UserDefaults.standard.string(forKey: currentUserKey)
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: currentUserKey)
        UserDefaults.standard.removeObject(forKey: "currentUserEmail")
        UserDefaults.standard.synchronize()
    }
    
    func isUserLoggedIn() -> Bool {
        return getCurrentUsername() != nil || UserDefaults.standard.string(forKey: "currentUserEmail") != nil
    }
    
    // MARK: - Debug Methods
    
    func printAllUsers() {
        getAllRegisteredUsers { users in
            print("\n=== USUARIOS REGISTRADOS (FIRESTORE) ===")
            if users.isEmpty {
                print("No hay usuarios registrados")
            } else {
                for user in users {
                    print("Usuario: \(user.username)")
                    print("Nombre: \(user.name)")
                    print("Email: \(user.email)")
                    print("Teléfono: \(user.phone ?? "No especificado")")
                    print("Registrado: \(user.registrationDate)")
                    print("---")
                }
            }
        }
    }
    
    func clearAllRegisteredUsers(completion: @escaping (Bool) -> Void) {
        db.collection(usersCollection).getDocuments { [weak self] querySnapshot, error in
            if let error = error {
                print("Error obteniendo usuarios para eliminar: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            let batch = self?.db.batch()
            
            querySnapshot?.documents.forEach { document in
                batch?.deleteDocument(document.reference)
            }
            
            batch?.commit { error in
                if let error = error {
                    print("Error eliminando usuarios: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Todos los usuarios han sido eliminados de Firestore")
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Profile Image Methods
    func updateProfileImage(imageBase64: String?, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            completion(false, "No hay usuario logueado")
            return
        }
        
        // Buscar el usuario por email
        getUser(by: currentUserEmail, byEmail: true) { [weak self] user in
            guard let self = self,
                  let user = user,
                  let userId = user.userId else {
                completion(false, "Usuario no encontrado")
                return
            }
            
            // Actualizar solo el campo imageProfile
            var updateData: [String: Any] = [:]
            
            if let imageBase64 = imageBase64 {
                updateData["imageProfile"] = imageBase64
            } else {
                // Si se pasa nil, eliminar la imagen de perfil
                updateData["imageProfile"] = FieldValue.delete()
            }
            
            self.db.collection(self.usersCollection)
                .document(userId)
                .updateData(updateData) { error in
                    if let error = error {
                        print("Error actualizando imagen de perfil: \(error.localizedDescription)")
                        completion(false, "Error actualizando imagen de perfil")
                    } else {
                        print("✅ Imagen de perfil actualizada exitosamente")
                        completion(true, nil)
                    }
                }
        }
    }
}

// MARK: - Synchronous wrapper methods for backward compatibility
extension UserManager {
    func isUsernameAvailable(_ username: String) -> Bool {
        // Esta versión síncrona se mantiene para compatibilidad
        // pero se recomienda usar la versión asíncrona
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        isUsernameAvailable(username) { isAvailable in
            result = isAvailable
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func validateCredentials(username: String, password: String) -> Bool {
        // Esta versión síncrona se mantiene para compatibilidad
        // pero se recomienda usar la versión asíncrona
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        validateCredentials(username: username, password: password) { isValid in
            result = isValid
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func registerUser(_ user: User) -> Bool {
        // Esta versión síncrona se mantiene para compatibilidad
        // pero se recomienda usar la versión asíncrona
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        registerUser(user) { success, _ in
            result = success
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
}
