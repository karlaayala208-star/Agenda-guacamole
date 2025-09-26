import UIKit
import CoreData

final class AgendaViewcontroller: UITableViewController {
    //TODO aqui hace algo
    var alumnos: [Person] = []

    // Obtener contexto desde AppDelegate (plantilla UIKit + Core Data)
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Agenda"
        cargarAlumnos()
    }
    
    // MARK: - Acción del botón + (conectar en Storyboard)
    @IBAction func agregarAlumno(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(
            title: "Nuevo Alumno",
            message: "Ingresa nombre, edad, curso y créditos",
            preferredStyle: .alert
        )
        
        alert.addTextField { $0.placeholder = "Nombre" }
        alert.addTextField {
            $0.placeholder = "Edad"
            $0.keyboardType = .numberPad
        }
        alert.addTextField { $0.placeholder = "Curso" }
        alert.addTextField {
            $0.placeholder = "Créditos"
            $0.keyboardType = .numberPad
        }
        
        let guardar = UIAlertAction(title: "Guardar", style: .default) { _ in
            guard
                let nombre = alert.textFields?[0].text, !nombre.isEmpty,
                let edadTexto = alert.textFields?[1].text, let edad = Int16(edadTexto),
                let cursoNombre = alert.textFields?[2].text, !cursoNombre.isEmpty,
                let creditosTexto = alert.textFields?[3].text, let creditos = Int16(creditosTexto)
            else {
                return
            }
            
            // Crear alumno
            let nuevoAlumno = Person(context: self.context)
            nuevoAlumno.nombre = nombre
            nuevoAlumno.edad = edad
            
//            // Crear curso
            let nuevoCurso = Hobbie(context: self.context)
            nuevoCurso.setValue(cursoNombre, forKey: "nombre")
            nuevoCurso.setValue(UUID(), forKey: "creditos")

            // Relación con KVC
            let alumnosSet = nuevoCurso.mutableSetValue(forKey: "alumnos")
            alumnosSet.add(nuevoAlumno)
            
            do {
                try self.context.save()
                self.cargarAlumnos()
            } catch {
                print("Error al guardar: \(error)")
            }
        }
        
        alert.addAction(guardar)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Cargar datos
    func cargarAlumnos() {
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        do {
            alumnos = try context.fetch(request)
            tableView.reloadData()
        } catch {
            print("Error al cargar alumnos: \(error)")
        }
    }
    
    // MARK: - TableView
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return alumnos.count
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlumnoCell", for: indexPath)
        let alumno = alumnos[indexPath.row]
        
        var cursoNombre = "Sin curso"
        var creditosTexto = ""
        
//        if let curso = alumno.value(forKey: "curso") as? Curso {
//            cursoNombre = curso.value(forKey: "nombre") as? String ?? "Sin curso"
//            if let c = curso.value(forKey: "creditos") as? Int16 {
//                creditosTexto = " - Créditos: \(c)"
//            }
//        }
        
        cell.textLabel?.text = alumno.nombre
        cell.detailTextLabel?.text = "Edad: \(alumno.edad) | Curso: \(cursoNombre)\(creditosTexto)"
        return cell
    }
    
    // Eliminar con swipe
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let alumno = alumnos[indexPath.row]
            context.delete(alumno)
            do {
                try context.save()
                alumnos.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                print("Error al eliminar: \(error)")
            }
        }
    }
}
