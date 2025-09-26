import UIKit
import MapKit

class DetailViewController: UIViewController {
    var person: Person?

    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        getPerson()
    }

    private func getPerson() {
        guard let person = person else {
            title = "Sin datos"
            infoLabel.text = "No hay información disponible"
            setupDefaultMap()
            return
        }
        
        title = person.nombre ?? "Sin nombre"

        //Mostrar la informacion de person en el label
        infoLabel.text = """
        📱 Teléfono: \(person.telefono ?? "No disponible")
        📍 Dirección: \(person.ubicacion ?? "No disponible")
        🎂 Edad: \(person.edad) años
        🎯 Hobbies: \(person.hobie ?? "Ninguno")
        """

        //Mostrar la ubicacion en el mapa solo si hay coordenadas válidas
        if person.latitude != 0 || person.longitude != 0 {
            let coord = CLLocationCoordinate2D(latitude: person.latitude, longitude: person.longitude)
            
            // configuracion region del mapa
            let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            mapView.setRegion(region, animated: false)

            //Agregar pin en el mapa
            let pin = MKPointAnnotation()
            pin.coordinate = coord
            pin.title = person.nombre ?? "Ubicación"
            pin.subtitle = person.ubicacion ?? "Punto seleccionado"
            mapView.addAnnotation(pin)
        } else {
            setupDefaultMap()
        }
    }
    
    private func setupDefaultMap() {
        // Si no hay coordenadas, mostrar una región por defecto (México)
        let defaultCoord = CLLocationCoordinate2D(latitude: 23.6345, longitude: -102.5528)
        let region = MKCoordinateRegion(center: defaultCoord, latitudinalMeters: 1000000, longitudinalMeters: 1000000)
        mapView.setRegion(region, animated: false)
    }
}
