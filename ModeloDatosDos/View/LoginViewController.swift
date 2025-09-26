import UIKit

class LoginViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var registerButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Debug: imprimir usuarios disponibles (puedes comentar esta línea en producción)
        UserManager.shared.printAllUsers()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Configurar title
        title = "Iniciar Sesión"
        
        // Configurar campos de texto
        usernameField.borderStyle = .roundedRect
        usernameField.placeholder = "Usuario"
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        
        passwordField.borderStyle = .roundedRect
        passwordField.placeholder = "Contraseña"
        passwordField.isSecureTextEntry = true
        passwordField.autocapitalizationType = .none
        passwordField.autocorrectionType = .no
        
        // Configurar botón de login
        loginButton.backgroundColor = UIColor.systemBlue
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        
        // Configurar botón de registro
        registerButton.backgroundColor = UIColor.clear
        registerButton.setTitleColor(UIColor.systemBlue, for: .normal)
        registerButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
    }
    
    // MARK: - Actions
    @IBAction func loginTapped(_ sender: UIButton) {
        guard let username = usernameField.text, !username.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Por favor, completa todos los campos")
            return
        }
        
        // Validación simple (puedes cambiar estos valores o implementar una validación más compleja)
        if validateCredentials(username: username, password: password) {
            // Guardar el usuario actual para uso en la app
            UserDefaults.standard.set(username, forKey: "CurrentUser")
            UserDefaults.standard.synchronize()
            
            // Login exitoso - navegar a la agenda
            navigateToAgenda()
        } else {
            showAlert(title: "Error de autenticación", message: "Usuario o contraseña incorrectos")
        }
    }
    
    @IBAction func registerTapped(_ sender: UIButton) {
        // Navegar al formulario de registro
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let registerVC = storyboard.instantiateViewController(withIdentifier: "RegisterViewController") as! RegisterViewController
        
        // Presentar como modal
        let navController = UINavigationController(rootViewController: registerVC)
        present(navController, animated: true)
    }
    
    // MARK: - Helper Methods
    private func validateCredentials(username: String, password: String) -> Bool {
        return UserManager.shared.validateCredentials(username: username, password: password)
    }
    
    private func navigateToAgenda() {
        // Crear el storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // Crear el navigation controller que ya está configurado en el storyboard
        guard let navController = storyboard.instantiateViewController(withIdentifier: "NavigationController") as? UINavigationController else {
            // Si no encuentra el navigation controller por ID, crear uno manualmente
            let agendaVC = storyboard.instantiateViewController(withIdentifier: "AgendaViewController") as! AgendaViewcontroller
            let navController = UINavigationController(rootViewController: agendaVC)
            setRootViewController(navController)
            return
        }
        
        setRootViewController(navController)
    }
    
    private func setRootViewController(_ viewController: UIViewController) {
        // Configurar como ventana principal
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = viewController
            
            // Animación de transición
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}