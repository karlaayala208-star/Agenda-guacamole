import UIKit

class RegisterViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var confirmPasswordField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Configurar title
        title = "Registrarse"
        
        // Configurar campos de texto
        setupTextField(nameField, placeholder: "Nombre completo")
        setupTextField(emailField, placeholder: "Correo electrónico")
        emailField.keyboardType = .emailAddress
        
        setupTextField(usernameField, placeholder: "Nombre de usuario")
        setupTextField(passwordField, placeholder: "Contraseña", isSecure: true)
        setupTextField(confirmPasswordField, placeholder: "Confirmar contraseña", isSecure: true)
        
        setupTextField(phoneField, placeholder: "Teléfono (opcional)")
        phoneField.keyboardType = .phonePad
        
        // Configurar botones
        registerButton.backgroundColor = UIColor.systemGreen
        registerButton.setTitleColor(.white, for: .normal)
        registerButton.layer.cornerRadius = 8
        registerButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        
        cancelButton.backgroundColor = UIColor.systemGray5
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.layer.cornerRadius = 8
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String, isSecure: Bool = false) {
        textField.borderStyle = .roundedRect
        textField.placeholder = placeholder
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.isSecureTextEntry = isSecure
    }
    
    private func setupNavigationBar() {
        // Agregar botón de cancelar en la navigation bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
    }
    
    // MARK: - Actions
    @IBAction func registerTapped(_ sender: UIButton) {
        // Validar campos
        guard let name = nameField.text, !name.isEmpty,
              let email = emailField.text, !email.isEmpty,
              let username = usernameField.text, !username.isEmpty,
              let password = passwordField.text, !password.isEmpty,
              let confirmPassword = confirmPasswordField.text, !confirmPassword.isEmpty else {
            showAlert(title: "Error", message: "Por favor, completa todos los campos obligatorios")
            return
        }
        
        // Validar email
        if !isValidEmail(email) {
            showAlert(title: "Error", message: "Por favor, ingresa un correo electrónico válido")
            return
        }
        
        // Validar username
        if username.count < 3 {
            showAlert(title: "Error", message: "El nombre de usuario debe tener al menos 3 caracteres")
            return
        }
        
        // Validar contraseña
        if password.count < 6 {
            showAlert(title: "Error", message: "La contraseña debe tener al menos 6 caracteres")
            return
        }
        
        // Validar confirmación de contraseña
        if password != confirmPassword {
            showAlert(title: "Error", message: "Las contraseñas no coinciden")
            return
        }
        
        // Validar que el usuario no exista (simulación)
        if isUsernameAvailable(username) {
            // Simular registro exitoso
            registerUser(name: name, email: email, username: username, password: password, phone: phoneField.text)
        } else {
            showAlert(title: "Error", message: "Este nombre de usuario ya está en uso")
        }
    }
    
    @IBAction func cancelTapped(_ sender: UIButton) {
        cancelRegistration()
    }

    private func cancelRegistration() {
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isUsernameAvailable(_ username: String) -> Bool {
        return UserManager.shared.isUsernameAvailable(username)
    }
    
    private func registerUser(name: String, email: String, username: String, password: String, phone: String?) {
        // Crear usuario con UserManager
        let user = User(name: name, email: email, username: username, password: password, phone: phone)
        
        if UserManager.shared.registerUser(user) {
            // Registro exitoso
            let alert = UIAlertController(
                title: "¡Registro exitoso!",
                message: "Tu cuenta ha sido creada correctamente. Ahora puedes iniciar sesión con el usuario: \(username)",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Iniciar sesión", style: .default) { [weak self] _ in
                self?.navigateToLogin()
            })
            
            present(alert, animated: true)
        } else {
            // Error en el registro
            showAlert(title: "Error", message: "No se pudo registrar el usuario. El nombre de usuario podría estar en uso.")
        }
    }
    
    private func navigateToLogin() {
        // Volver al login
        dismiss(animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
