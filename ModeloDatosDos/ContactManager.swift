import Foundation
import FirebaseFirestore

// MARK: - Contact Model
struct Contact {
    let id: String
    let nombre: String
    let telefono: String?
    let direccion: String?
    let edad: Int?
    let hobbies: String?
    let latitude: Double?
    let longitude: Double?
    let profileImage: String? // Base64 encoded image
    let createdAt: Date
    
    init(id: String = UUID().uuidString, nombre: String, telefono: String? = nil, direccion: String? = nil, edad: Int? = nil, hobbies: String? = nil, latitude: Double? = nil, longitude: Double? = nil, profileImage: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.nombre = nombre
        self.telefono = telefono
        self.direccion = direccion
        self.edad = edad
        self.hobbies = hobbies
        self.latitude = latitude
        self.longitude = longitude
        self.profileImage = profileImage
        self.createdAt = createdAt
    }
    
    init?(from dictionary: [String: Any]) {
        guard let nombre = dictionary["nombre"] as? String else { return nil }
        
        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.nombre = nombre
        self.telefono = dictionary["telefono"] as? String
        self.direccion = dictionary["direccion"] as? String
        self.edad = dictionary["edad"] as? Int
        self.hobbies = dictionary["hobbies"] as? String
        self.latitude = dictionary["latitude"] as? Double
        self.longitude = dictionary["longitude"] as? Double
        self.profileImage = dictionary["profileImage"] as? String
        
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "nombre": nombre,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let telefono = telefono, !telefono.isEmpty {
            dict["telefono"] = telefono
        }
        
        if let direccion = direccion, !direccion.isEmpty {
            dict["direccion"] = direccion
        }
        
        if let edad = edad {
            dict["edad"] = edad
        }
        
        if let hobbies = hobbies, !hobbies.isEmpty {
            dict["hobbies"] = hobbies
        }
        
        if let latitude = latitude {
            dict["latitude"] = latitude
        }
        
        if let longitude = longitude {
            dict["longitude"] = longitude
        }
        
        if let profileImage = profileImage, !profileImage.isEmpty {
            dict["profileImage"] = profileImage
        }
        
        return dict
    }
}

// MARK: - Contact Manager
class ContactManager {
    static let shared = ContactManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Add Contact (with parameters)
    func addContact(nombre: String, telefono: String?, direccion: String?, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            print("Error: No hay usuario logueado")
            completion(false)
            return
        }
        
        UserManager.shared.getUser(by: currentUserEmail, byEmail: true) { user in
            guard let user = user, let userId = user.userId else {
                print("Error: Usuario no encontrado o sin ID")
                completion(false)
                return
            }
            
            let contact = Contact(
                id: UUID().uuidString,
                nombre: nombre,
                telefono: telefono,
                direccion: direccion,
                createdAt: Date()
            )
            
            let contactData = contact.toDictionary()
            
            self.db.collection("users").document(userId).collection("contacts").addDocument(data: contactData) { error in
                if let error = error {
                    print("Error agregando contacto: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Contacto agregado exitosamente")
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Add Contact (with Contact object)
    func addContact(_ contact: Contact, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            completion(.failure(NSError(domain: "ContactManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No hay usuario logueado"])))
            return
        }
        
        UserManager.shared.getUser(by: currentUserEmail, byEmail: true) { user in
            guard let user = user, let userId = user.userId else {
                completion(.failure(NSError(domain: "ContactManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no encontrado"])))
                return
            }
            
            let contactData = contact.toDictionary()
            
            self.db.collection("users").document(userId).collection("contacts").addDocument(data: contactData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Get Contacts (simple callback)
    func getContacts(completion: @escaping ([Contact]) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            print("Error: No hay usuario logueado")
            completion([])
            return
        }
        
        UserManager.shared.getUser(by: currentUserEmail, byEmail: true) { user in
            guard let user = user, let userId = user.userId else {
                print("Error: Usuario no encontrado o sin ID")
                completion([])
                return
            }
            
            self.db.collection("users")
                .document(userId)
                .collection("contacts")
                .order(by: "nombre")
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error obteniendo contactos: \(error.localizedDescription)")
                        completion([])
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        completion([])
                        return
                    }
                    
                    let contacts = documents.compactMap { doc -> Contact? in
                        let data = doc.data()
                        guard let nombre = data["nombre"] as? String else { return nil }
                        
                        let telefono = data["telefono"] as? String
                        let direccion = data["direccion"] as? String
                        let edad = data["edad"] as? Int
                        let hobbies = data["hobbies"] as? String
                        let latitude = data["latitude"] as? Double
                        let longitude = data["longitude"] as? Double
                        let profileImage = data["profileImage"] as? String
                        
                        return Contact(
                            id: doc.documentID,
                            nombre: nombre,
                            telefono: telefono?.isEmpty == true ? nil : telefono,
                            direccion: direccion?.isEmpty == true ? nil : direccion,
                            edad: edad,
                            hobbies: hobbies?.isEmpty == true ? nil : hobbies,
                            latitude: latitude,
                            longitude: longitude,
                            profileImage: profileImage?.isEmpty == true ? nil : profileImage
                        )
                    }
                    
                    completion(contacts)
                }
        }
    }
    
    // MARK: - Get Contacts (Result callback)
    func getContacts(completion: @escaping (Result<[Contact], Error>) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            completion(.failure(NSError(domain: "ContactManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No hay usuario logueado"])))
            return
        }
        
        UserManager.shared.getUser(by: currentUserEmail, byEmail: true) { user in
            guard let user = user, let userId = user.userId else {
                completion(.failure(NSError(domain: "ContactManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no encontrado"])))
                return
            }
            
            self.db.collection("users")
                .document(userId)
                .collection("contacts")
                .order(by: "nombre")
                .getDocuments { snapshot, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        completion(.success([]))
                        return
                    }
                    
                    let contacts = documents.compactMap { doc -> Contact? in
                        let data = doc.data()
                        guard let nombre = data["nombre"] as? String else { return nil }
                        
                        let telefono = data["telefono"] as? String
                        let direccion = data["direccion"] as? String
                        let edad = data["edad"] as? Int
                        let hobbies = data["hobbies"] as? String
                        let latitude = data["latitude"] as? Double
                        let longitude = data["longitude"] as? Double
                        let profileImage = data["profileImage"] as? String
                        
                        return Contact(
                            id: doc.documentID,
                            nombre: nombre,
                            telefono: telefono?.isEmpty == true ? nil : telefono,
                            direccion: direccion?.isEmpty == true ? nil : direccion,
                            edad: edad,
                            hobbies: hobbies?.isEmpty == true ? nil : hobbies,
                            latitude: latitude,
                            longitude: longitude,
                            profileImage: profileImage?.isEmpty == true ? nil : profileImage
                        )
                    }
                    
                    completion(.success(contacts))
                }
        }
    }
    
    // MARK: - Update Contact
    func updateContact(_ contact: Contact, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            completion(.failure(NSError(domain: "ContactManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No hay usuario logueado"])))
            return
        }
        
        UserManager.shared.getUser(by: currentUserEmail, byEmail: true) { user in
            guard let user = user, let userId = user.userId else {
                completion(.failure(NSError(domain: "ContactManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no encontrado"])))
                return
            }
            
            let contactData: [String: Any] = [
                "nombre": contact.nombre,
                "telefono": contact.telefono ?? "",
                "direccion": contact.direccion ?? "",
                "profileImage": contact.profileImage ?? ""
            ]
            
            self.db.collection("users")
                .document(userId)
                .collection("contacts")
                .document(contact.id)
                .updateData(contactData) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
        }
    }
    
    // MARK: - Delete Contact
    func deleteContact(_ contact: Contact, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            completion(.failure(NSError(domain: "ContactManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No hay usuario logueado"])))
            return
        }
        
        UserManager.shared.getUser(by: currentUserEmail, byEmail: true) { user in
            guard let user = user, let userId = user.userId else {
                completion(.failure(NSError(domain: "ContactManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no encontrado"])))
                return
            }
            
            self.db.collection("users")
                .document(userId)
                .collection("contacts")
                .document(contact.id)
                .delete { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
        }
    }
}