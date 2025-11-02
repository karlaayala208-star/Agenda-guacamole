import UIKit
import CoreData

final class AgendaViewcontroller: UITableViewController {
    
    // MARK: - Profile Section Outlets
    @IBOutlet weak var profileContainerView: UIView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userEmailLabel: UILabel!
    
    /// variable que almacena las persona a mostrar en la agenda
    var persons: [Person] = []
    /// Diccionario para organizar personas por letra inicial
    var personsByLetter: [String: [Person]] = [:]
    /// Array con las letras ordenadas para las secciones
    var sortedLetters: [String] = []

    // Obtener contexto desde AppDelegate (plantilla UIKit + Core Data)
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Verificar que hay un usuario logueado
        guard UserManager.shared.isUserLoggedIn() else {
            // Si no hay usuario logueado, regresar al login
            navigateToLogin()
            return
        }
        
        setupProfileSection()
        setupNavigationBar()
        
        // Debug: Agregar botón temporal para mostrar todos los contactos
        addDebugButton()
        
        fetchPersons()
    }
    
    private func addDebugButton() {
        let debugButton = UIBarButtonItem(title: "Debug", style: .plain, target: self, action: #selector(showAllContacts))
        if let rightButton = navigationItem.rightBarButtonItem {
            navigationItem.rightBarButtonItems = [rightButton, debugButton]
        } else {
            navigationItem.rightBarButtonItem = debugButton
        }
    }
    
    @objc private func showAllContacts() {
        let alert = UIAlertController(title: "Debug", message: "¿Mostrar todos los contactos sin filtrar?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sí", style: .default) { [weak self] _ in
            self?.fetchAllPersons()
        })
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        present(alert, animated: true)
    }
    
    private func fetchAllPersons() {
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        
        do {
            persons = try context.fetch(request)
            print("📊 TODOS los contactos mostrados: \(persons.count)")
            organizePersonsByLetter()
            tableView.reloadData()
        } catch {
            print("❌ Error fetching all persons: \(error)")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Recargar datos cuando regresamos a esta pantalla
        fetchPersons()
        // Actualizar información del perfil
        loadUserProfile()
    }
    
    private func setupProfileSection() {
        // Configurar la vista del perfil si existe
        if let profileContainer = profileContainerView {
            profileContainer.backgroundColor = UIColor.systemBackground
            profileContainer.layer.cornerRadius = 12
            profileContainer.layer.shadowColor = UIColor.black.cgColor
            profileContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
            profileContainer.layer.shadowRadius = 4
            profileContainer.layer.shadowOpacity = 0.1
        }
        
        // Configurar imagen de perfil
        if let profileImage = profileImageView {
            profileImage.layer.cornerRadius = 30 // Para hacer circular (asumiendo 60x60)
            profileImage.clipsToBounds = true
            profileImage.contentMode = .scaleAspectFill
            profileImage.backgroundColor = UIColor.systemGray5
            
            // Imagen por defecto
            profileImage.image = createDefaultProfileImage()
        }
        
        // Configurar labels
        if let nameLabel = userNameLabel {
            nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            nameLabel.textColor = UIColor.label
        }
        
        if let emailLabel = userEmailLabel {
            emailLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            emailLabel.textColor = UIColor.secondaryLabel
        }
        
        // Cargar información del usuario
        loadUserProfile()
        
        // Configurar título simplificado
        title = "Contactos"
    }
    
    private func createDefaultProfileImage() -> UIImage? {
        let size = CGSize(width: 60, height: 60)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        // Fondo circular
        UIColor.systemBlue.setFill()
        let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
        path.fill()
        
        // Icono de persona
        let personImage = UIImage(systemName: "person.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        let imageRect = CGRect(x: 15, y: 15, width: 30, height: 30)
        personImage?.draw(in: imageRect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func loadUserProfile() {
        UserManager.shared.getCurrentUser { [weak self] user in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let user = user {
                    self.userNameLabel?.text = user.name
                    self.userEmailLabel?.text = user.email
                } else {
                    // Fallback si no se puede obtener el usuario
                    self.userNameLabel?.text = "Usuario"
                    if let email = UserDefaults.standard.string(forKey: "currentUserEmail") {
                        self.userEmailLabel?.text = email
                    } else if let username = UserManager.shared.getCurrentUsername() {
                        self.userEmailLabel?.text = username
                    } else {
                        self.userEmailLabel?.text = "Sin información"
                    }
                }
            }
        }
        
        // Configurar gesto para la imagen de perfil
        setupProfileImageGesture()
    }
    
    // MARK: - Profile Image Methods
    @objc private func profileImageTapped() {
        // Funcionalidad futura para cambiar imagen de perfil
        let alert = UIAlertController(title: "Imagen de Perfil", message: "Funcionalidad próximamente disponible", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func setupProfileImageGesture() {
        if let profileImage = profileImageView {
            profileImage.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(profileImageTapped))
            profileImage.addGestureRecognizer(tapGesture)
        }
    }
    
    private func setupNavigationBar() {
        // Botón para agregar persona
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPerson))
        
        // Botón para logout
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Salir", style: .plain, target: self, action: #selector(logoutTapped))
    }

    @objc func addPerson() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AddPersonViewController") as! AddPersonViewController
        vc.onSave = { [weak self] in
            self?.fetchPersons()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    func fetchPersons() {
        // Intentar obtener el usuario actual
        var currentUserIdentifier: String?
        
        // Primero intentar obtener el email del usuario actual
        if let currentEmail = UserDefaults.standard.string(forKey: "currentUserEmail") {
            currentUserIdentifier = currentEmail
            print("🔍 Usuario logueado por EMAIL: \(currentEmail)")
        } else if let currentUsername = UserManager.shared.getCurrentUsername() {
            currentUserIdentifier = currentUsername
            print("🔍 Usuario logueado por USERNAME: \(currentUsername)")
        }
        
        guard let userIdentifier = currentUserIdentifier else {
            print("❌ No hay usuario logueado")
            persons = []
            tableView.reloadData()
            return
        }
        
        // Primero, migrar datos existentes sin propietario
        migrateExistingPersonsIfNeeded()
        
        // Migrar contactos del username al email si es necesario
        migratePersonsFromUsernameToEmail(currentIdentifier: userIdentifier)
        
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        
        // Filtrar solo las personas del usuario actual (compatibilidad con email y username)
        request.predicate = NSPredicate(format: "ownerUsername == %@", userIdentifier)
        
        // Ordenar alfabéticamente por nombre
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        
        do {
            persons = try context.fetch(request)
            print("📊 Contactos encontrados para '\(userIdentifier)': \(persons.count)")
            
            // Debug: Mostrar todos los contactos en la base de datos
            debugAllPersons()
            
            organizePersonsByLetter()
            tableView.reloadData()
        } catch {
            print("❌ Error fetching persons: \(error)")
        }
    }
    
    // MARK: - Debug Methods
    private func debugAllPersons() {
        let allRequest: NSFetchRequest<Person> = Person.fetchRequest()
        do {
            let allPersons = try context.fetch(allRequest)
            print("🗃️ TODOS los contactos en la base de datos:")
            for person in allPersons {
                print("  - \(person.nombre ?? "Sin nombre") -> Owner: '\(person.ownerUsername ?? "nil")'")
            }
        } catch {
            print("❌ Error debugging persons: \(error)")
        }
    }
    
    // Organizar personas por letra inicial
    private func organizePersonsByLetter() {
        personsByLetter.removeAll()
        
        for person in persons {
            let firstLetter = getFirstLetter(from: person.nombre ?? "")
            if personsByLetter[firstLetter] == nil {
                personsByLetter[firstLetter] = []
            }
            personsByLetter[firstLetter]?.append(person)
        }
        
        // Ordenar las letras alfabéticamente
        sortedLetters = personsByLetter.keys.sorted()
    }
    
    private func migrateExistingPersonsIfNeeded() {
        // Solo ejecutar una vez
        let migrationKey = "PersonOwnerMigrationCompleted"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        request.predicate = NSPredicate(format: "ownerUsername == nil OR ownerUsername == ''")
        
        do {
            let personsWithoutOwner = try context.fetch(request)
            if !personsWithoutOwner.isEmpty {
                // Obtener el identificador del usuario actual (email o username)
                var defaultOwner = "admin"
                if let currentEmail = UserDefaults.standard.string(forKey: "currentUserEmail") {
                    defaultOwner = currentEmail
                } else if let currentUsername = UserManager.shared.getCurrentUsername() {
                    defaultOwner = currentUsername
                }
                
                for person in personsWithoutOwner {
                    person.ownerUsername = defaultOwner
                }
                
                try context.save()
                print("Migradas \(personsWithoutOwner.count) personas al usuario: \(defaultOwner)")
            }
            
            UserDefaults.standard.set(true, forKey: migrationKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("❌ Error en migración: \(error)")
        }
    }
    
    private func migratePersonsFromUsernameToEmail(currentIdentifier: String) {
        // Solo migrar si el usuario actual está logueado por email
        guard currentIdentifier.contains("@") else { return }
        
        // Obtener el usuario actual para obtener su username
        UserManager.shared.getCurrentUser { [weak self] user in
            guard let self = self,
                  let user = user else { return }

            let username = user.username
            
            DispatchQueue.main.async {
                let migrationKey = "PersonEmailMigrationCompleted_\(user.email)"
                guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
                
                let request: NSFetchRequest<Person> = Person.fetchRequest()
                request.predicate = NSPredicate(format: "ownerUsername == %@", username.lowercased())
                
                do {
                    let personsWithUsername = try self.context.fetch(request)
                    if !personsWithUsername.isEmpty {
                        print("🔄 Migrando \(personsWithUsername.count) contactos de username '\(username)' a email '\(user.email)'")
                        
                        for person in personsWithUsername {
                            person.ownerUsername = user.email.lowercased()
                        }
                        
                        try self.context.save()
                        print("✅ Migración completada exitosamente")
                        
                        // Recargar los contactos después de la migración
                        self.fetchPersons()
                    }
                    
                    UserDefaults.standard.set(true, forKey: migrationKey)
                    UserDefaults.standard.synchronize()
                } catch {
                    print("❌ Error en migración de username a email: \(error)")
                }
            }
        }
    }
    
    @objc func logoutTapped() {
        let alert = UIAlertController(
            title: "Cerrar sesión",
            message: "¿Estás seguro de que quieres cerrar sesión?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cerrar sesión", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        
        present(alert, animated: true)
    }
    
    private func performLogout() {
        UserManager.shared.logout()
        navigateToLogin()
    }
    
    private func navigateToLogin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as! LoginViewController
        
        // Configurar como ventana principal
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = loginVC
            
            // Animación de transición
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }
    
    // MARK: - TableView DataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sortedLetters.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let letter = sortedLetters[section]
        return personsByLetter[letter]?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sortedLetters[section]
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sortedLetters
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlumnoCell", for: indexPath)
        
        // Obtener la persona de la sección y fila correspondiente
        let letter = sortedLetters[indexPath.section]
        guard let personsInSection = personsByLetter[letter],
              indexPath.row < personsInSection.count else {
            return cell
        }
        
        let person = personsInSection[indexPath.row]
        
        // Mostrar solo el nombre del contacto
        cell.textLabel?.text = person.nombre ?? "Sin nombre"
        
        // Limpiar el detailTextLabel para que no muestre información adicional
        cell.detailTextLabel?.text = nil
        
        return cell
    }
    
    // Helper function para obtener la primera letra en mayúscula
    private func getFirstLetter(from name: String) -> String {
        guard let firstChar = name.first else { return "#" }
        let letter = String(firstChar).uppercased()
        
        // Verificar si es una letra válida del alfabeto
        let alphabetRange = "A"..."Z"
        return alphabetRange.contains(letter) ? letter : "#"
    }
    
    // MARK: - Swipe Actions
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let letter = sortedLetters[indexPath.section]
        guard let personsInSection = personsByLetter[letter],
              indexPath.row < personsInSection.count else {
            return nil
        }
        
        let person = personsInSection[indexPath.row]
        
        // Acción de eliminar
        let deleteAction = UIContextualAction(style: .destructive, title: "Eliminar") { [weak self] (action, view, completionHandler) in
            self?.deletePerson(person, at: indexPath)
            completionHandler(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        // Acción de editar
        let editAction = UIContextualAction(style: .normal, title: "Editar") { [weak self] (action, view, completionHandler) in
            self?.editPerson(person)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "pencil")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false // Evita que el swipe completo elimine automáticamente
        
        return configuration
    }
    
    // Método para eliminar persona
    private func deletePerson(_ person: Person, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Eliminar contacto",
            message: "¿Estás seguro de que quieres eliminar a \(person.nombre ?? "esta persona")?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { [weak self] _ in
            self?.performDelete(person)
        })
        
        present(alert, animated: true)
    }
    
    private func performDelete(_ person: Person) {
        context.delete(person)
        
        do {
            try context.save()
            fetchPersons() // Recargar datos después de eliminar
        } catch {
            print("Error al eliminar: \(error)")
            showAlert(title: "Error", message: "No se pudo eliminar el contacto. Inténtalo de nuevo.")
        }
    }
    
    // Método para editar persona
    private func editPerson(_ person: Person) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let editVC = storyboard.instantiateViewController(withIdentifier: "AddPersonViewController") as! AddPersonViewController
        
        // Configurar el controlador para modo edición
        editVC.title = "Editar Contacto"
        editVC.personToEdit = person
        editVC.onSave = { [weak self] in
            self?.fetchPersons()
        }
        
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Navigation
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deseleccionar la celda con animación
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Obtener la persona seleccionada de la sección correspondiente
        let letter = sortedLetters[indexPath.section]
        guard let personsInSection = personsByLetter[letter],
              indexPath.row < personsInSection.count else {
            return
        }
        
        let selectedPerson = personsInSection[indexPath.row]
        
        // Crear el DetailViewController
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let detailVC = storyboard.instantiateViewController(withIdentifier: "DetailViewController") as! DetailViewController
        detailVC.person = selectedPerson
        
        // Navegar al detalle
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
