import UIKit
import CoreData
import MapKit

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

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Nueva Persona"
        
        setupMapView()
        addGestureRecognizerToMapView()
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

    @IBAction func saveTapped(_ sender: Any) {
        let person = Person(context: context)
        person.id = UUID()
        person.nombre = nameField.text ?? ""
        person.telefono = phoneField.text ?? ""
        person.ubicacion = addressField.text ?? ""
        person.edad = Int16(ageField.text ?? "0") ?? 0
        person.hobie = hobbiesField.text ?? ""

        // Coordenadas
        person.latitude = selectedLocation?.latitude ?? 0
        person.longitude = selectedLocation?.longitude ?? 0

        do {
            try context.save()
            onSave?()
            navigationController?.popViewController(animated: true)
        } catch {
            print("Error saving person: \(error)")
        }
    }
}
