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

    var onSave: (() -> Void)?
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var selectedLocation: CLLocationCoordinate2D?
    private let geocoder = CLGeocoder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Nueva Persona"
        
        setupMapView()
        addGestureRecognizerToMapView()
        setupTextFields()
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
        // Configurar el delegate para el campo de dirección
        addressField.delegate = self
        
        // Agregar target para cuando se termine de editar la dirección
        addressField.addTarget(self, action: #selector(addressFieldDidEndEditing), for: .editingDidEnd)
        addressField.addTarget(self, action: #selector(addressFieldDidChange), for: .editingChanged)
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
        // Verificar que hay un usuario logueado
        guard let currentUsername = UserManager.shared.getCurrentUsername() else {
            showAlert(title: "Error", message: "No hay un usuario logueado. Por favor, inicia sesión.")
            return
        }
        
        let person = Person(context: context)
        person.id = UUID()
        person.nombre = nameField.text ?? ""
        person.telefono = phoneField.text ?? ""
        person.ubicacion = addressField.text ?? ""
        person.edad = Int16(ageField.text ?? "0") ?? 0
        person.hobie = hobbiesField.text ?? ""
        person.ownerUsername = currentUsername // Asignar el usuario propietario

        // Coordenadas
        person.latitude = selectedLocation?.latitude ?? 0
        person.longitude = selectedLocation?.longitude ?? 0

        do {
            try context.save()
            onSave?()
            navigationController?.popViewController(animated: true)
        } catch {
            print("Error saving person: \(error)")
            showAlert(title: "Error", message: "No se pudo guardar la persona. Inténtalo de nuevo.")
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
        if textField == addressField {
            textField.resignFirstResponder()
            geocodeAddress()
            return false
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == addressField {
            geocodeAddress()
        }
    }
}
