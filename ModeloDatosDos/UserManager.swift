import Foundation

struct User {
    let name: String
    let email: String
    let username: String
    let password: String
    let phone: String?
    let registrationDate: Date
    
    init(name: String, email: String, username: String, password: String, phone: String? = nil, registrationDate: Date = Date()) {
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
            "email": email,
            "username": username,
            "password": password,
            "registrationDate": registrationDate.timeIntervalSince1970
        ]
        
        if let phone = phone {
            dict["phone"] = phone
        }
        
        return dict
    }
}

class UserManager {
    static let shared = UserManager()
    private let userDefaultsKey = "RegisteredUsers"

    private init() {}
    
    // MARK: - Public Methods
    
    func registerUser(_ user: User) -> Bool {
        // Verificar que el usuario no exista
        if isUsernameAvailable(user.username) {
            var registeredUsers = getRegisteredUsers()
            registeredUsers[user.username.lowercased()] = user.toDictionary()
            
            UserDefaults.standard.set(registeredUsers, forKey: userDefaultsKey)
            UserDefaults.standard.synchronize()
            
            return true
        }
        return false
    }
    
    func isUsernameAvailable(_ username: String) -> Bool {
        let lowercaseUsername = username.lowercased()
        
        // Verificar usuarios registrados
        let registeredUsers = getRegisteredUsers()
        return registeredUsers[lowercaseUsername] == nil
    }
    
    func validateCredentials(username: String, password: String) -> Bool {
        let lowercaseUsername = username.lowercased()
        
        // Verificar usuarios registrados
        let registeredUsers = getRegisteredUsers()
        if let userData = registeredUsers[lowercaseUsername],
           let storedPassword = userData["password"] as? String {
            return storedPassword == password
        }
        
        return false
    }
    
    func getUser(by username: String) -> User? {
        let registeredUsers = getRegisteredUsers()
        guard let userData = registeredUsers[username.lowercased()] else {
            return nil
        }
        
        return User(from: userData)
    }
    
    func getAllRegisteredUsers() -> [User] {
        let registeredUsers = getRegisteredUsers()
        return registeredUsers.compactMap { User(from: $0.value) }
    }
    
    // MARK: - Current User Management
    
    func setCurrentUser(_ username: String) {
        UserDefaults.standard.set(username.lowercased(), forKey: "CurrentUser")
        UserDefaults.standard.synchronize()
    }
    
    func getCurrentUser() -> User? {
        guard let currentUsername = UserDefaults.standard.string(forKey: "CurrentUser") else {
            return nil
        }
        return getUser(by: currentUsername)
    }
    
    func getCurrentUsername() -> String? {
        return UserDefaults.standard.string(forKey: "CurrentUser")
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "CurrentUser")
        UserDefaults.standard.synchronize()
    }
    
    func isUserLoggedIn() -> Bool {
        return getCurrentUsername() != nil
    }
    
    // MARK: - Private Methods
    
    private func getRegisteredUsers() -> [String: [String: Any]] {
        return UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: [String: Any]] ?? [:]
    }
    
    // MARK: - Debug Methods
    
    func printAllUsers() {
        print("\n=== USUARIOS REGISTRADOS ===")
        let users = getAllRegisteredUsers()
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
    
    func clearAllRegisteredUsers() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()
        print("Todos los usuarios registrados han sido eliminados")
    }
}
