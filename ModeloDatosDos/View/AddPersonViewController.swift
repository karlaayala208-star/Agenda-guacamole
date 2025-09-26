import UIKit
import CoreData
import MapKit

class AddPersonViewController: UIViewController {
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var ageField: UITextField!
    @IBOutlet weak var hobbiesField: UITextField!

    var onSave: (() -> Void)?
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var selectedLocation: CLLocationCoordinate2D?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Nueva Persona"
    }

    @IBAction func saveTapped(_ sender: Any) {
//        let person = Person(context: context)
//        person.id = UUID()
//        person.name = nameField.text ?? ""
//        person.phone = phoneField.text ?? ""
//        person.address = addressField.text ?? ""
//        person.age = Int16(ageField.text ?? "0") ?? 0
//        person.hobbies = hobbiesField.text ?? ""
//        person.latitude = selectedLocation?.latitude ?? 0
//        person.longitude = selectedLocation?.longitude ?? 0

        do {
            try context.save()
            onSave?()
            navigationController?.popViewController(animated: true)
        } catch {
            print("Error saving person: \(error)")
        }
    }
}
