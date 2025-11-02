import UIKit
import MapKit

class DetailViewController: UIViewController {
    var contact: Contact?

    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        getContact()
    }

    private func getContact() {
        guard let contact = contact else {
            title = "Sin datos"
            infoLabel.text = "No hay información disponible"
            setupDefaultMap()
            return
        }
        
        title = contact.nombre

        //Mostrar la informacion del contacto en el label
        var infoText = """
        📱 Teléfono: \(contact.telefono ?? "No disponible")
        📍 Dirección: \(contact.direccion ?? "No disponible")
        """
        
        if let edad = contact.edad {
            infoText += "\n🎂 Edad: \(edad) años"
        }
        
        if let hobbies = contact.hobbies, !hobbies.isEmpty {
            infoText += "\n🎯 Hobbies: \(hobbies)"
        }
        
        infoLabel.text = infoText

        // Configurar mapa con coordenadas del contacto si están disponibles
        setupMap()
    }
    
    private func setupMap() {
        guard let contact = contact,
              let latitude = contact.latitude,
              let longitude = contact.longitude else {
            setupDefaultMap()
            return
        }
        
        // Usar las coordenadas guardadas del contacto
        let contactLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(center: contactLocation, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(region, animated: false)
        
        // Agregar un pin en la ubicación del contacto
        let annotation = MKPointAnnotation()
        annotation.coordinate = contactLocation
        annotation.title = contact.nombre
        annotation.subtitle = contact.direccion
        mapView.addAnnotation(annotation)
    }
    
    private func setupDefaultMap() {
        // Si no hay coordenadas, mostrar una región por defecto (México)
        let defaultCoord = CLLocationCoordinate2D(latitude: 23.6345, longitude: -102.5528)
        let region = MKCoordinateRegion(center: defaultCoord, latitudinalMeters: 1000000, longitudinalMeters: 1000000)
        mapView.setRegion(region, animated: false)
    }
}
