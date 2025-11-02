import UIKit
import CoreData
import MapKit
import CoreLocation

class AddPersonViewController: UIViewController {
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var ageField: UITextField!
    @IBOutlet weak var hobbiesField: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var saveButton: UIButton!

    var onSave: (() -> Void)?
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var selectedLocation: CLLocationCoordinate2D?
    private let geocoder = CLGeocoder()
    
    // Propiedad para modo edición
    var personToEdit: Person?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = personToEdit != nil ? "Editar Contacto" : "Nueva Persona"
        
        setupMapView()
        addGestureRecognizerToMapView()
        setupTextFields()
        
        // Si estamos editando, cargar los datos existentes
        if let person = personToEdit {
            loadPersonData(person)
        }
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
        let buttonTitle = personToEdit != nil ? "Actualizar" : "Guardar"
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
        // Verificar validación del formulario
        guard isFormValid() else {
            showValidationAlert()
            return
        }
        
        // Verificar que hay un usuario logueado y obtener su identificador
        var currentUserIdentifier: String?
        if let currentEmail = UserDefaults.standard.string(forKey: "currentUserEmail") {
            currentUserIdentifier = currentEmail
        } else if let currentUsername = UserManager.shared.getCurrentUsername() {
            currentUserIdentifier = currentUsername
        }
        
        guard let userIdentifier = currentUserIdentifier else {
            showAlert(title: "Error", message: "No hay un usuario logueado. Por favor, inicia sesión.")
            return
        }
        
        let person: Person
        
        if let existingPerson = personToEdit {
            // Modo edición - actualizar persona existente
            person = existingPerson
        } else {
            // Modo creación - crear nueva persona
            person = Person(context: context)
            person.id = UUID()
            person.ownerUsername = userIdentifier // Asignar el identificador del usuario (email o username)
        }
        
        // Actualizar campos (tanto para crear como para editar)
        person.nombre = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        person.telefono = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        person.ubicacion = addressField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        person.edad = Int16(ageField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") ?? 0
        person.hobie = hobbiesField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Coordenadas
        person.latitude = selectedLocation?.latitude ?? 0
        person.longitude = selectedLocation?.longitude ?? 0

        do {
            try context.save()
            onSave?()
            navigationController?.popViewController(animated: true)
        } catch {
            print("Error saving person: \(error)")
            let action = personToEdit != nil ? "actualizar" : "guardar"
            showAlert(title: "Error", message: "No se pudo \(action) la persona. Inténtalo de nuevo.")
        }
    }
    
    private func showValidationAlert() {
        var message = "Por favor, completa los siguientes campos correctamente:\n\n"
        
        if let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines), name.isEmpty || name.count < 2 {
            message += "• Nombre (mínimo 2 caracteres)\n"
        }
        
        if let phone = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines), phone.isEmpty || phone.count < 8 {
            message += "• Teléfono (mínimo 8 dígitos)\n"
        }
        
        if let address = addressField.text?.trimmingCharacters(in: .whitespacesAndNewlines), address.isEmpty || address.count < 5 {
            message += "• Dirección (mínimo 5 caracteres)\n"
        }
        
        if let ageText = ageField.text?.trimmingCharacters(in: .whitespacesAndNewlines), ageText.isEmpty || Int(ageText) == nil || Int(ageText)! <= 0 || Int(ageText)! > 120 {
            message += "• Edad (entre 1 y 120 años)\n"
        }
        
        showAlert(title: "Formulario incompleto", message: message)
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
    private func loadPersonData(_ person: Person) {
        nameField.text = person.nombre
        phoneField.text = person.telefono
        addressField.text = person.ubicacion
        ageField.text = person.edad > 0 ? String(person.edad) : ""
        hobbiesField.text = person.hobie
        
        // Cargar ubicación si existe
        if person.latitude != 0 || person.longitude != 0 {
            let coordinate = CLLocationCoordinate2D(latitude: person.latitude, longitude: person.longitude)
            selectedLocation = coordinate
            
            // Agregar pin al mapa
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = person.nombre ?? "Ubicación"
            annotation.subtitle = person.ubicacion
            mapView.addAnnotation(annotation)
            
            // Centrar mapa en la ubicación
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
            mapView.setRegion(region, animated: false)
        }
        
        // Validar formulario después de cargar datos
        DispatchQueue.main.async {
            self.validateForm()
        }
    }
}
