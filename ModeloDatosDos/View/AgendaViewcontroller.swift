import UIKit
import CoreData

final class AgendaViewcontroller: UITableViewController {
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
        
        setupTitle()
        setupNavigationBar()
        fetchPersons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Recargar datos cuando regresamos a esta pantalla
        fetchPersons()
    }
    
    private func setupNavigationBar() {
        // Botón para agregar persona
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPerson))
        
        // Botón para logout
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Salir", style: .plain, target: self, action: #selector(logoutTapped))
    }
    
    private func setupTitle() {
        // Mostrar el usuario actual si está disponible
        if let user = UserManager.shared.getCurrentUser() {
            title = "Agenda - \(user.name)"
        } else if let currentUsername = UserManager.shared.getCurrentUsername() {
            title = "Agenda - \(currentUsername)"
        } else {
            title = "Agenda"
        }
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
        guard let currentUsername = UserManager.shared.getCurrentUsername() else {
            print("No hay usuario logueado")
            persons = []
            tableView.reloadData()
            return
        }
        
        // Primero, migrar datos existentes sin propietario
        migrateExistingPersonsIfNeeded()
        
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        
        // Filtrar solo las personas del usuario actual
        request.predicate = NSPredicate(format: "ownerUsername == %@", currentUsername)
        
        // Ordenar alfabéticamente por nombre
        request.sortDescriptors = [NSSortDescriptor(key: "nombre", ascending: true)]
        
        do {
            persons = try context.fetch(request)
            organizePersonsByLetter()
            tableView.reloadData()
        } catch {
            print("Error fetching persons: \(error)")
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
                // Asignar todos los contactos existentes al primer usuario disponible
                // o a un usuario por defecto
                let defaultOwner = UserManager.shared.getCurrentUsername() ?? "admin"
                
                for person in personsWithoutOwner {
                    person.ownerUsername = defaultOwner
                }
                
                try context.save()
                print("Migradas \(personsWithoutOwner.count) personas al usuario: \(defaultOwner)")
            }
            
            UserDefaults.standard.set(true, forKey: migrationKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error en migración: \(error)")
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
    
    // Eliminar con swipe
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let letter = sortedLetters[indexPath.section]
            guard let personsInSection = personsByLetter[letter],
                  indexPath.row < personsInSection.count else {
                return
            }
            
            let personToDelete = personsInSection[indexPath.row]
            
            // Eliminar de Core Data
            context.delete(personToDelete)
            
            do {
                try context.save()
                // Recargar datos después de eliminar
                fetchPersons()
            } catch {
                print("Error al eliminar: \(error)")
            }
        }
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
