import UIKit
import CoreData

final class AgendaViewcontroller: UITableViewController {
    /// variable que almacena las persona a mostrar en la agenda
    var persons: [Person] = []

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
        
        do {
            persons = try context.fetch(request)
            tableView.reloadData()
        } catch {
            print("Error fetching persons: \(error)")
        }
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

    // MARK: - Acción del botón + (conectar en Storyboard)
    @IBAction func agregarAlumno(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(
            title: "Nuevo Alumno",
            message: "Ingresa nombre, edad, curso y créditos",
            preferredStyle: .alert
        )
        
        alert.addTextField { $0.placeholder = "Nombre" }
        alert.addTextField {
            $0.placeholder = "Edad"
            $0.keyboardType = .numberPad
        }
        alert.addTextField { $0.placeholder = "Curso" }
        alert.addTextField {
            $0.placeholder = "Créditos"
            $0.keyboardType = .numberPad
        }
        
        let guardar = UIAlertAction(title: "Guardar", style: .default) { _ in
            guard
                let nombre = alert.textFields?[0].text, !nombre.isEmpty,
                let edadTexto = alert.textFields?[1].text, let edad = Int16(edadTexto),
                let cursoNombre = alert.textFields?[2].text, !cursoNombre.isEmpty,
                let creditosTexto = alert.textFields?[3].text, let creditos = Int16(creditosTexto)
            else {
                return
            }
            
            // Crear alumno
            let nuevoAlumno = Person(context: self.context)
            nuevoAlumno.nombre = nombre
            nuevoAlumno.edad = edad
            
//            // Crear curso
            let nuevoCurso = Hobbie(context: self.context)
            nuevoCurso.setValue(cursoNombre, forKey: "nombre")
            nuevoCurso.setValue(UUID(), forKey: "creditos")

            // Relación con KVC
            let alumnosSet = nuevoCurso.mutableSetValue(forKey: "alumnos")
            alumnosSet.add(nuevoAlumno)
            
            do {
                try self.context.save()
                self.cargarAlumnos()
            } catch {
                print("Error al guardar: \(error)")
            }
        }
        
        alert.addAction(guardar)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Cargar datos
    func cargarAlumnos() {
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        do {
            persons = try context.fetch(request)
            tableView.reloadData()
        } catch {
            print("Error al cargar alumnos: \(error)")
        }
    }
    
    // MARK: - TableView
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return persons.count
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlumnoCell", for: indexPath)
        let alumno = persons[indexPath.row]
        
        var cursoNombre = "Sin curso"
        var creditosTexto = ""
        
//        if let curso = alumno.value(forKey: "curso") as? Curso {
//            cursoNombre = curso.value(forKey: "nombre") as? String ?? "Sin curso"
//            if let c = curso.value(forKey: "creditos") as? Int16 {
//                creditosTexto = " - Créditos: \(c)"
//            }
//        }
        
        cell.textLabel?.text = alumno.nombre
        cell.detailTextLabel?.text = "Edad: \(alumno.edad) | Curso: \(cursoNombre)\(creditosTexto)"
        return cell
    }
    
    // Eliminar con swipe
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let alumno = persons[indexPath.row]
            context.delete(alumno)
            do {
                try context.save()
                persons.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                print("Error al eliminar: \(error)")
            }
        }
    }
    
    // MARK: - Navigation
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deseleccionar la celda con animación
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Obtener la persona seleccionada
        let selectedPerson = persons[indexPath.row]
        
        // Crear el DetailViewController
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let detailVC = storyboard.instantiateViewController(withIdentifier: "DetailViewController") as! DetailViewController
        detailVC.person = selectedPerson
        
        // Navegar al detalle
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
