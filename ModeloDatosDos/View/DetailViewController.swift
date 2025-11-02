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

        // Por ahora, mostrar mapa por defecto ya que Contact no tiene coordenadas
        setupDefaultMap()
    }
    
    private func setupDefaultMap() {
        // Si no hay coordenadas, mostrar una región por defecto (México)
        let defaultCoord = CLLocationCoordinate2D(latitude: 23.6345, longitude: -102.5528)
        let region = MKCoordinateRegion(center: defaultCoord, latitudinalMeters: 1000000, longitudinalMeters: 1000000)
        mapView.setRegion(region, animated: false)
    }
}
