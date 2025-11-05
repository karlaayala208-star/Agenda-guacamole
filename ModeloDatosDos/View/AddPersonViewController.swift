import UIKit
import MapKit
import CoreLocation
import PhotosUI

class AddPersonViewController: UIViewController, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var ageField: UITextField!
    @IBOutlet weak var hobbiesField: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var saveButton: UIButton!

    var onSave: (() -> Void)?
    var selectedLocation: CLLocationCoordinate2D?
    private let geocoder = CLGeocoder()
    private var selectedProfileImage: UIImage?
    
    // Propiedad para modo edición
    var contactToEdit: Contact?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = contactToEdit != nil ? "Editar Contacto" : "Nueva Persona"
        
        setupProfileImageView()
        setupMapView()
        addGestureRecognizerToMapView()
        setupTextFields()
        
        // Si estamos editando, cargar los datos existentes
        if let contact = contactToEdit {
            loadContactData(contact)
        }
    }
    
    private func setupProfileImageView() {
        guard let profileImageView = profileImageView else { return }
        
        // Configurar la imagen de perfil
        profileImageView.layer.cornerRadius = 50 // Para hacer circular (asumiendo 100x100)
        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.backgroundColor = UIColor.systemGray5
        
        // Imagen por defecto inicialmente
        profileImageView.image = createDefaultProfileImage()
        
        // Configurar gesture para tap
        profileImageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(profileImageTapped))
        profileImageView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func profileImageTapped() {
        presentImagePicker()
    }
    
    private func presentImagePicker() {
        let alert = UIAlertController(title: "Seleccionar imagen", message: "Elige una opción", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Galería", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        
        alert.addAction(UIAlertAction(title: "Quitar imagen", style: .destructive) { [weak self] _ in
            self?.removeProfileImage()
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        // Para iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = profileImageView
            popover.sourceRect = profileImageView.bounds
        }
        
        present(alert, animated: true)
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
    
    private func removeProfileImage() {
        selectedProfileImage = nil
        profileImageView?.image = createDefaultProfileImage()
    }
    
    private func createDefaultProfileImage() -> UIImage? {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        // Fondo circular
        UIColor.systemGray4.setFill()
        let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
        path.fill()
        
        // Icono de persona
        let personImage = UIImage(systemName: "person.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        let imageRect = CGRect(x: 25, y: 25, width: 50, height: 50)
        personImage?.draw(in: imageRect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
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
    
    private func updateProfileImage(_ image: UIImage) {
        // Redimensionar la imagen para optimizar el almacenamiento
        let resizedImage = resizeImage(image, to: CGSize(width: 200, height: 200))
        selectedProfileImage = resizedImage
        
        // Actualizar la UI inmediatamente
        profileImageView?.image = resizedImage
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func setupMapView() {
        // Habilitar todas las interacciones del mapa
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        
        // Configurar el tipo de mapa
        mapView.mapType = .standard
        
        // Configurar región inicial (México)
        let initialLocation = CLLocationCoordinate2D(latitude: 23.6345, longitude: -102.5528)
        let regionRadius: CLLocationDistance = 1000000 // 1000 km
        let coordinateRegion = MKCoordinateRegion(center: initialLocation, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
        mapView.setRegion(coordinateRegion, animated: false)
        
        // Mostrar la ubicación del usuario si está disponible
        mapView.showsUserLocation = true
    }
    
    private func setupTextFields() {
        // Configurar delegates para todos los campos
        nameField.delegate = self
        phoneField.delegate = self
        addressField.delegate = self
        ageField.delegate = self
        hobbiesField.delegate = self
        
        // Agregar targets para validación en tiempo real
        nameField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        phoneField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addressField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        ageField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        hobbiesField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        // Configurar targets específicos para dirección
        addressField.addTarget(self, action: #selector(addressFieldDidEndEditing), for: .editingDidEnd)
        addressField.addTarget(self, action: #selector(addressFieldDidChange), for: .editingChanged)
        
        // Configurar botón inicialmente deshabilitado
        setupSaveButton()
        validateForm()
    }
    
    private func setupSaveButton() {
        saveButton.layer.cornerRadius = 8
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        
        // Cambiar el texto del botón según el modo
    let buttonTitle = contactToEdit != nil ? "Actualizar" : "Guardar"
        saveButton.setTitle(buttonTitle, for: .normal)
        
        updateSaveButtonState(isEnabled: false)
    }
    
    private func updateSaveButtonState(isEnabled: Bool) {
        saveButton.isEnabled = isEnabled
        if isEnabled {
            saveButton.backgroundColor = UIColor.systemBlue
            saveButton.setTitleColor(.white, for: .normal)
            saveButton.alpha = 1.0
        } else {
            saveButton.backgroundColor = UIColor.systemGray4
            saveButton.setTitleColor(.systemGray2, for: .normal)
            saveButton.alpha = 0.6
        }
    }
    
    @objc private func textFieldDidChange() {
        validateForm()
        
        // Cancelar geocoding si está escribiendo en dirección
        if addressField.isFirstResponder {
            geocoder.cancelGeocode()
        }
    }
    
    private func validateForm() {
        let isValid = isFormValid()
        updateSaveButtonState(isEnabled: isValid)
    }
    
    private func isFormValid() -> Bool {
        // Campos requeridos: nombre, teléfono, dirección y edad
        guard let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              name.count >= 2 else { return false }
        
        guard let phone = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !phone.isEmpty,
              phone.count >= 8 else { return false }
        
        guard let address = addressField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty,
              address.count >= 5 else { return false }
        
        guard let ageText = ageField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !ageText.isEmpty,
              let age = Int(ageText),
              age > 0 && age <= 120 else { return false }
        
        // Hobbies es opcional, no se valida
        
        return true
    }

    private func addGestureRecognizerToMapView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapOnMapView))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.numberOfTouchesRequired = 1
        // Permitir que otros gestos del mapa funcionen simultáneamente
        tapGestureRecognizer.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc func handleTapOnMapView(gestureRecognizer: UIGestureRecognizer) {
        // Solo responder a taps simples (no a doble taps o gestos complejos)
        if gestureRecognizer.state == .ended {
            let locationPoint = gestureRecognizer.location(in: mapView)
            let coordinate = mapView.convert(locationPoint, toCoordinateFrom: mapView)
            selectedLocation = coordinate

            // Quitar anotaciones anteriores
            mapView.removeAnnotations(mapView.annotations)

            // Agregar un pin
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Punto Seleccionado"
            annotation.subtitle = "Lat: \(String(format: "%.4f", coordinate.latitude)), Lon: \(String(format: "%.4f", coordinate.longitude))"
            mapView.addAnnotation(annotation)
            
            // Animar la vista hacia el punto seleccionado
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 10000, longitudinalMeters: 10000)
            mapView.setRegion(region, animated: true)
        }
    }
    
    // MARK: - Address Geocoding
    @objc private func addressFieldDidEndEditing() {
        geocodeAddress()
    }
    
    @objc private func addressFieldDidChange() {
        // Cancelar geocoding anterior si el usuario está escribiendo
        geocoder.cancelGeocode()
    }
    
    private func geocodeAddress() {
        guard let address = addressField.text,
              !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              address.count > 3 else {
            return
        }
        
        // Mostrar indicador de carga (opcional)
        // Puedes agregar un activity indicator aquí
        
        geocoder.geocodeAddressString(address) { [weak self] (placemarks, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Error de geocodificación: \(error.localizedDescription)")
                    // Optionally show an alert to the user
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    print("No se encontró ubicación para la dirección: \(address)")
                    return
                }
                
                self.updateMapWithLocation(location.coordinate, address: address, placemark: placemark)
            }
        }
    }
    
    private func updateMapWithLocation(_ coordinate: CLLocationCoordinate2D, address: String, placemark: CLPlacemark) {
        selectedLocation = coordinate
        
        // Quitar anotaciones anteriores
        mapView.removeAnnotations(mapView.annotations)
        
        // Crear anotación con información detallada
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = placemark.name ?? address
        
        // Crear subtítulo más informativo
        var subtitleComponents: [String] = []
        if let locality = placemark.locality {
            subtitleComponents.append(locality)
        }
        if let country = placemark.country {
            subtitleComponents.append(country)
        }
        annotation.subtitle = subtitleComponents.isEmpty ? address : subtitleComponents.joined(separator: ", ")
        
        mapView.addAnnotation(annotation)
        
        // Animar hacia la ubicación encontrada
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
        mapView.setRegion(region, animated: true)
        
        // Opcional: Actualizar el campo de dirección con la dirección formateada
        if let formattedAddress = placemark.name {
            addressField.text = formattedAddress
        }
    }

    @IBAction func saveTapped(_ sender: Any) {
        // Verificar validación del formulario básico
        guard let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines), 
              !name.isEmpty else {
            showAlert(title: "Error", message: "El nombre es obligatorio.")
            return
        }
        
        let phone = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = addressField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ageText = ageField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hobbies = hobbiesField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Convertir edad a Int si se proporciona
        var age: Int? = nil
        if let ageText = ageText, !ageText.isEmpty {
            age = Int(ageText)
        }
        
        // Convertir imagen a base64 si existe
        var profileImageBase64: String? = nil
        if let image = selectedProfileImage {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                profileImageBase64 = imageData.base64EncodedString()
            }
        }
        
        if let existingContact = contactToEdit {
            // Modo edición - actualizar contacto existente
            let updatedContact = Contact(
                id: existingContact.id,
                nombre: name,
                telefono: phone,
                direccion: address,
                edad: age,
                hobbies: hobbies,
                latitude: selectedLocation?.latitude,
                longitude: selectedLocation?.longitude,
                profileImage: profileImageBase64
            )
            
            ContactManager.shared.updateContact(updatedContact) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Contacto actualizado exitosamente")
                        self?.onSave?()
                        self?.navigationController?.popViewController(animated: true)
                        
                    case .failure(let error):
                        print("❌ Error actualizando contacto: \(error)")
                        self?.showAlert(title: "Error", message: "No se pudo actualizar el contacto. Inténtalo de nuevo.")
                    }
                }
            }
        } else {
            // Modo creación - crear nuevo contacto
            let newContact = Contact(
                nombre: name,
                telefono: phone,
                direccion: address,
                edad: age,
                hobbies: hobbies,
                latitude: selectedLocation?.latitude,
                longitude: selectedLocation?.longitude,
                profileImage: profileImageBase64
            )
            
            ContactManager.shared.addContact(newContact) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Contacto creado exitosamente")
                        self?.onSave?()
                        self?.navigationController?.popViewController(animated: true)
                        
                    case .failure(let error):
                        print("❌ Error creando contacto: \(error)")
                        self?.showAlert(title: "Error", message: "No se pudo guardar el contacto. Inténtalo de nuevo.")
                    }
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension AddPersonViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Mover al siguiente campo o cerrar teclado
        switch textField {
        case nameField:
            phoneField.becomeFirstResponder()
        case phoneField:
            addressField.becomeFirstResponder()
        case addressField:
            textField.resignFirstResponder()
            geocodeAddress()
        case ageField:
            hobbiesField.becomeFirstResponder()
        case hobbiesField:
            textField.resignFirstResponder()
        default:
            textField.resignFirstResponder()
        }
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == addressField {
            geocodeAddress()
        }
        validateForm() // Validar cuando termine de editar cualquier campo
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Validaciones específicas por campo
        if textField == ageField {
            // Solo permitir números en el campo edad
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        
        if textField == phoneField {
            // Permitir números, espacios, guiones y paréntesis para teléfono
            let allowedCharacters = CharacterSet(charactersIn: "0123456789 ()-+")
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        
        return true
    }
}

// MARK: - Edit Mode Support
extension AddPersonViewController {
    private func loadContactData(_ contact: Contact) {
        nameField.text = contact.nombre
        phoneField.text = contact.telefono
        addressField.text = contact.direccion
        ageField.text = contact.edad != nil ? String(contact.edad!) : nil
        hobbiesField.text = contact.hobbies
        
        // Cargar imagen de perfil si existe
        if let profileImageBase64 = contact.profileImage,
           let imageData = Data(base64Encoded: profileImageBase64),
           let image = UIImage(data: imageData) {
            selectedProfileImage = image
            profileImageView?.image = image
        } else {
            selectedProfileImage = nil
            profileImageView?.image = createDefaultProfileImage()
        }
        
        // Si hay coordenadas, mostrar en el mapa
        if let latitude = contact.latitude, let longitude = contact.longitude {
            selectedLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            // Quitar anotaciones anteriores
            mapView.removeAnnotations(mapView.annotations)
            
            // Agregar anotación
            let annotation = MKPointAnnotation()
            annotation.coordinate = selectedLocation!
            annotation.title = "Ubicación guardada"
            annotation.subtitle = contact.direccion ?? "Sin dirección"
            mapView.addAnnotation(annotation)
            
            // Centrar el mapa en la ubicación
            let region = MKCoordinateRegion(center: selectedLocation!, latitudinalMeters: 5000, longitudinalMeters: 5000)
            mapView.setRegion(region, animated: false)
        }
        
        // Validar formulario después de cargar datos
        DispatchQueue.main.async {
            self.validateForm()
        }
    }
}
