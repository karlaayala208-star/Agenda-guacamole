import Foundation
import FirebaseFirestore

struct User {
    let userId: String?
    let name: String
    let email: String
    let username: String
    let password: String
    let phone: String?
    let registrationDate: Date
    
    init(name: String, email: String, username: String, password: String, phone: String? = nil, registrationDate: Date = Date(), userId: String? = nil) {
        self.userId = userId
        self.name = name
        self.email = email
        self.username = username
        self.password = password
        self.phone = phone
        self.registrationDate = registrationDate
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
        
        return dict
    }
}

class UserManager {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let currentUserKey = "CurrentUser"
    
    private init() {}
    
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
    
    func getCurrentUser(completion: @escaping (User?) -> Void) {
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
        UserDefaults.standard.synchronize()
    }
    
    func isUserLoggedIn() -> Bool {
        return getCurrentUsername() != nil
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
