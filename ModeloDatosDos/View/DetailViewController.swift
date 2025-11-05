import UIKit
import MapKit

class DetailViewController: UIViewController {
    var contact: Contact?

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupProfileImageView()
        getContact()
    }
    
    private func setupProfileImageView() {
        guard let profileImageView = profileImageView else { return }
        
        // Configurar la imagen de perfil
        profileImageView.layer.cornerRadius = 50 // Para hacer circular
        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.backgroundColor = UIColor.systemGray5
    }

    private func getContact() {
        guard let contact = contact else {
            title = "Sin datos"
            infoLabel.text = "No hay información disponible"
            setupDefaultMap()
            return
        }
        
        title = contact.nombre
        
        // Configurar imagen de perfil
        setupContactProfileImage(contact)

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
    
    private func setupContactProfileImage(_ contact: Contact) {
        guard let profileImageView = profileImageView else { return }
        
        // Cargar imagen de perfil o usar imagen por defecto
        if let profileImageBase64 = contact.profileImage,
           let imageData = Data(base64Encoded: profileImageBase64),
           let profileImage = UIImage(data: imageData) {
            profileImageView.image = profileImage
        } else {
            // Usar imagen por defecto con iniciales
            profileImageView.image = createDefaultContactImage(for: contact.nombre)
        }
    }
    
    private func createDefaultContactImage(for name: String) -> UIImage? {
        let size = CGSize(width: 100, height: 100)
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
            .font: UIFont.systemFont(ofSize: 32, weight: .medium),
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
