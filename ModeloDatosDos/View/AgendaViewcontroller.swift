import UIKit
import PhotosUI

final class AgendaViewcontroller: UITableViewController, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Profile Section Outlets
    @IBOutlet weak var profileContainerView: UIView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userEmailLabel: UILabel!
    
    /// variable que almacena los contactos a mostrar en la agenda
    var contacts: [Contact] = []
    /// Diccionario para organizar contactos por letra inicial
    var contactsByLetter: [String: [Contact]] = [:]
    /// Array con las letras ordenadas para las secciones
    var sortedLetters: [String] = []
    
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
        fetchContacts()
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
        let alert = UIAlertController(title: "Debug", message: "Información de contactos en Firestore", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Mostrar info", style: .default) { [weak self] _ in
            self?.showDebugInfo()
        })
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showDebugInfo() {
        print("Contactos actuales: \(contacts.count)")
        for contact in contacts {
            print("  - \(contact.nombre)")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Recargar datos cuando regresamos a esta pantalla
        fetchContacts()
        // Actualizar información del perfil
        loadUserProfile()
    }
    
    func fetchContacts() {
        ContactManager.shared.getContacts { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let fetchedContacts):
                    self.contacts = fetchedContacts
                    print("Contactos obtenidos de Firestore: \(fetchedContacts.count)")
                    self.organizeContactsByLetter()
                    self.tableView.reloadData()
                    
                case .failure(let error):
                    print("Error obteniendo contactos: \(error)")
                    self.showAlert(title: "Error", message: "No se pudieron cargar los contactos.")
                    self.contacts = []
                    self.tableView.reloadData()
                }
            }
        }
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
            
            // Imagen por defecto inicialmente
            profileImage.image = createDefaultProfileImage()
            
            // Configurar gesture para tap
            profileImage.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(profileImageTapped))
            profileImage.addGestureRecognizer(tapGesture)
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
                    
                    // Cargar imagen de perfil si existe
                    if let imageBase64 = user.imageProfile,
                       let imageData = Data(base64Encoded: imageBase64),
                       let image = UIImage(data: imageData) {
                        self.profileImageView?.image = image
                    } else {
                        // Usar imagen por defecto si no hay imagen guardada
                        self.profileImageView?.image = self.createDefaultProfileImage()
                    }
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
                    self.profileImageView?.image = self.createDefaultProfileImage()
                }
            }
        }
    }
    
    // MARK: - Profile Image Methods
    @objc private func profileImageTapped() {
        presentPhotoLibrary()
    }

    private func presentPhotoLibrary() {
        if #available(iOS 14, *) {
            // Usar PHPickerViewController para iOS 14+
            var config = PHPickerConfiguration()
            config.selectionLimit = 1
            config.filter = .images
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true)
        } else {
            // Fallback para versiones anteriores
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            present(picker, animated: true)
        }
    }
    
    // MARK: - PHPickerViewControllerDelegate
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let error = error {
                print("Error cargando imagen: \(error)")
                return
            }
            
            if let image = object as? UIImage {
                DispatchQueue.main.async {
                    self?.updateProfileImage(image)
                }
            }
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        var selectedImage: UIImage?
        
        if let editedImage = info[.editedImage] as? UIImage {
            selectedImage = editedImage
        } else if let originalImage = info[.originalImage] as? UIImage {
            selectedImage = originalImage
        }
        
        if let image = selectedImage {
            updateProfileImage(image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    // MARK: - Image Processing
    private func updateProfileImage(_ image: UIImage) {
        // Redimensionar la imagen para optimizar el almacenamiento
        let resizedImage = resizeImage(image, to: CGSize(width: 200, height: 200))
        
        // Actualizar la UI inmediatamente
        profileImageView.image = resizedImage
        
        // Convertir a base64 y guardar en Firestore
        if let imageData = resizedImage.jpegData(compressionQuality: 0.8) {
            let imageBase64 = imageData.base64EncodedString()
            saveProfileImageToFirestore(imageBase64)
        }
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func saveProfileImageToFirestore(_ imageBase64: String?) {
        UserManager.shared.updateProfileImage(imageBase64: imageBase64) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("Imagen de perfil guardada en Firestore")
                } else {
                    print("Error guardando imagen de perfil: \(error ?? "Error desconocido")")
                    self?.showImageSaveError()
                }
            }
        }
    }
    
    private func showImageSaveError() {
        let alert = UIAlertController(
            title: "Error",
            message: "No se pudo guardar la imagen de perfil. Inténtalo de nuevo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
            self?.fetchContacts()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    // Organizar contactos por letra inicial
    private func organizeContactsByLetter() {
        contactsByLetter.removeAll()
        
        for contact in contacts {
            let firstLetter = getFirstLetter(from: contact.nombre)
            if contactsByLetter[firstLetter] == nil {
                contactsByLetter[firstLetter] = []
            }
            contactsByLetter[firstLetter]?.append(contact)
        }
        
        // Ordenar las letras alfabéticamente
        sortedLetters = contactsByLetter.keys.sorted()
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
        return contactsByLetter[letter]?.count ?? 0
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
        
        // Obtener el contacto de la sección y fila correspondiente
        let letter = sortedLetters[indexPath.section]
        guard let contactsInSection = contactsByLetter[letter],
              indexPath.row < contactsInSection.count else {
            return cell
        }
        
        let contact = contactsInSection[indexPath.row]
        
        // Mostrar solo el nombre del contacto
        cell.textLabel?.text = contact.nombre
        
        // Limpiar el detailTextLabel para que no muestre información adicional
        cell.detailTextLabel?.text = nil
        
        // Configurar imagen de perfil
        setupContactProfileImage(for: cell, contact: contact)
        
        return cell
    }
    
    private func setupContactProfileImage(for cell: UITableViewCell, contact: Contact) {
        // Crear o configurar el imageView si no existe
        if cell.imageView?.image == nil {
            cell.imageView?.contentMode = .scaleAspectFill
            cell.imageView?.layer.cornerRadius = 20 // Radio para imagen circular (40x40)
            cell.imageView?.clipsToBounds = true
            cell.imageView?.backgroundColor = UIColor.systemGray5
        }
        
        // Cargar imagen de perfil o usar imagen por defecto
        if let profileImageBase64 = contact.profileImage,
           let imageData = Data(base64Encoded: profileImageBase64),
           let profileImage = UIImage(data: imageData) {
            // Redimensionar la imagen para la celda
            let resizedImage = resizeImageForCell(profileImage, to: CGSize(width: 40, height: 40))
            cell.imageView?.image = resizedImage
        } else {
            // Usar imagen por defecto
            cell.imageView?.image = createDefaultContactImage(for: contact.nombre)
        }
    }
    
    private func createDefaultContactImage(for name: String) -> UIImage? {
        let size = CGSize(width: 40, height: 40)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        // Obtener las iniciales del nombre
        let initials = getInitials(from: name)
        
        // Generar color de fondo basado en el nombre
        let backgroundColor = generateColor(from: name)
        
        // Fondo circular
        backgroundColor.setFill()
        let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
        path.fill()
        
        // Dibujar iniciales
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        
        let textSize = initials.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        initials.draw(in: textRect, withAttributes: attributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
        
        if components.count >= 2 {
            let firstName = String(components[0].prefix(1)).uppercased()
            let lastName = String(components[1].prefix(1)).uppercased()
            return firstName + lastName
        } else if let firstChar = components.first?.first {
            return String(firstChar).uppercased()
        }
        
        return "?"
    }
    
    private func generateColor(from name: String) -> UIColor {
        // Generar un color consistente basado en el hash del nombre
        let hash = name.hash
        let colors: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange, .systemPurple,
            .systemRed, .systemTeal, .systemIndigo, .systemPink,
            .systemBrown, .systemGray
        ]
        
        let index = abs(hash) % colors.count
        return colors[index]
    }
    
    private func resizeImageForCell(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
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
        guard let contactsInSection = contactsByLetter[letter],
              indexPath.row < contactsInSection.count else {
            return nil
        }
        
        let contact = contactsInSection[indexPath.row]
        
        // Acción de eliminar
        let deleteAction = UIContextualAction(style: .destructive, title: "Eliminar") { [weak self] (action, view, completionHandler) in
            self?.deleteContact(contact, at: indexPath)
            completionHandler(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        // Acción de editar
        let editAction = UIContextualAction(style: .normal, title: "Editar") { [weak self] (action, view, completionHandler) in
            self?.editContact(contact)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "pencil")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false // Evita que el swipe completo elimine automáticamente
        
        return configuration
    }
    
    // Método para eliminar contacto
    private func deleteContact(_ contact: Contact, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Eliminar contacto",
            message: "¿Estás seguro de que quieres eliminar a \(contact.nombre)?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { [weak self] _ in
            self?.performDeleteContact(contact)
        })
        
        present(alert, animated: true)
    }
    
    private func performDeleteContact(_ contact: Contact) {
        ContactManager.shared.deleteContact(contact) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Contacto eliminado exitosamente")
                    self?.fetchContacts() // Recargar datos después de eliminar
                    
                case .failure(let error):
                    print("Error al eliminar contacto: \(error)")
                    self?.showAlert(title: "Error", message: "No se pudo eliminar el contacto. Inténtalo de nuevo.")
                }
            }
        }
    }
    
    // Método para editar contacto
    private func editContact(_ contact: Contact) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let editVC = storyboard.instantiateViewController(withIdentifier: "AddPersonViewController") as! AddPersonViewController
        
        // Configurar el controlador para modo edición
        editVC.title = "Editar Contacto"
        editVC.contactToEdit = contact
        editVC.onSave = { [weak self] in
            self?.fetchContacts()
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
        
        // Obtener el contacto seleccionado de la sección correspondiente
        let letter = sortedLetters[indexPath.section]
        guard let contactsInSection = contactsByLetter[letter],
              indexPath.row < contactsInSection.count else {
            return
        }
        
        let selectedContact = contactsInSection[indexPath.row]
        
        // Crear el DetailViewController
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let detailVC = storyboard.instantiateViewController(withIdentifier: "DetailViewController") as! DetailViewController
        detailVC.contact = selectedContact
        
        // Navegar al detalle
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
