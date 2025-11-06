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
        setupKeyboardHandling()
        setupTextFieldDelegates()
        setupKeyboardObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeKeyboardObservers()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Configurar title
        title = "Registrarse"
        
        // Configurar campos de texto
        setupTextField(nameField, placeholder: "Nombre completo")
        nameField.returnKeyType = .next
        
        setupTextField(emailField, placeholder: "Correo electrónico")
        emailField.keyboardType = .emailAddress
        emailField.returnKeyType = .next
        
        setupTextField(usernameField, placeholder: "Nombre de usuario")
        usernameField.returnKeyType = .next
        
        setupTextField(passwordField, placeholder: "Contraseña", isSecure: true)
        passwordField.returnKeyType = .next
        
        setupTextField(confirmPasswordField, placeholder: "Confirmar contraseña", isSecure: true)
        confirmPasswordField.returnKeyType = .next
        
        setupTextField(phoneField, placeholder: "Teléfono (opcional)")
        phoneField.keyboardType = .phonePad
        setupPhoneFieldToolbar()
        
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
    
    private func setupKeyboardHandling() {
        // Agregar tap gesture para ocultar el teclado
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupPhoneFieldToolbar() {
        // Crear toolbar para el campo de teléfono
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        // Crear botón flexible para empujar el botón Done a la derecha
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // Crear botón Done
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        
        // Agregar botones al toolbar
        toolbar.items = [flexibleSpace, doneButton]
        
        // Asignar toolbar al campo de teléfono
        phoneField.inputAccessoryView = toolbar
    }
    
    private func setupTextFieldDelegates() {
        nameField.delegate = self
        emailField.delegate = self
        usernameField.delegate = self
        passwordField.delegate = self
        confirmPasswordField.delegate = self
        phoneField.delegate = self
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        // Ajustar el contenido para que no se oculte detrás del teclado
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.contentInset = contentInsets
            scrollView.scrollIndicatorInsets = contentInsets
            
            // Hacer scroll hacia el campo activo si está oculto
            if let activeField = view.subviews.first(where: { $0.isFirstResponder }) {
                let rect = activeField.frame
                scrollView.scrollRectToVisible(rect, animated: true)
            }
        } else {
            // Si no hay scroll view, mover la vista hacia arriba
            let visibleHeight = view.frame.height - keyboardHeight
            let activeFieldBottom = getActiveFieldMaxY()
            
            if activeFieldBottom > visibleHeight {
                let offset = activeFieldBottom - visibleHeight + 20 // 20 puntos de margen
                UIView.animate(withDuration: 0.3) {
                    self.view.frame.origin.y = -offset
                }
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.contentInset = .zero
            scrollView.scrollIndicatorInsets = .zero
        } else {
            UIView.animate(withDuration: 0.3) {
                self.view.frame.origin.y = 0
            }
        }
    }
    
    private func getActiveFieldMaxY() -> CGFloat {
        let textFields = [nameField, emailField, usernameField, passwordField, confirmPasswordField, phoneField]
        
        for field in textFields {
            if field?.isFirstResponder == true {
                return field?.frame.maxY ?? 0
            }
        }
        
        return 0
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
        
        // Validar que el usuario no exista (validación asíncrona)
        isUsernameAvailable(username) { [weak self] isAvailable in
            DispatchQueue.main.async {
                if isAvailable {
                    // Simular registro exitoso
                    self?.registerUser(name: name, email: email, username: username, password: password, phone: self?.phoneField.text)
                } else {
                    self?.showAlert(title: "Error", message: "Este nombre de usuario ya está en uso")
                }
            }
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
    
    private func isUsernameAvailable(_ username: String, completion: @escaping (Bool) -> Void) {
        UserManager.shared.isUsernameAvailable(username, completion: completion)
    }
    
    private func registerUser(name: String, email: String, username: String, password: String, phone: String?) {
        // Mostrar indicador de carga
        registerButton.isEnabled = false
        registerButton.setTitle("Registrando...", for: .normal)
        
        // Crear usuario con UserManager usando Firebase Auth
        let user = User(name: name, email: email, username: username, password: password, phone: phone)
        
        UserManager.shared.registerUserWithAuth(user) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                self?.registerButton.isEnabled = true
                self?.registerButton.setTitle("Registrarse", for: .normal)
                
                if success {
                    // Registro exitoso - mostrar mensaje de verificación
                    let alert = UIAlertController(
                        title: "¡Registro exitoso!",
                        message: "Tu cuenta ha sido creada correctamente. Hemos enviado un email de verificación a \(email). Por favor, verifica tu email antes de iniciar sesión.",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "Entendido", style: .default) { _ in
                        self?.navigateToLogin()
                    })
                    
                    // Agregar opción para reenviar email de verificación
                    alert.addAction(UIAlertAction(title: "Reenviar email", style: .default) { _ in
                        self?.resendVerificationEmail()
                    })
                    
                    self?.present(alert, animated: true)
                } else {
                    // Error en el registro
                    let message = errorMessage ?? "No se pudo registrar el usuario. Inténtalo de nuevo."
                    self?.showAlert(title: "Error", message: message)
                }
            }
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
    
    private func resendVerificationEmail() {
        UserManager.shared.resendVerificationEmail { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    self?.showAlert(title: "Email enviado", message: "El email de verificación ha sido reenviado. Revisa tu bandeja de entrada.")
                } else {
                    let message = errorMessage ?? "No se pudo enviar el email de verificación"
                    self?.showAlert(title: "Error", message: message)
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension RegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameField:
            emailField.becomeFirstResponder()
        case emailField:
            usernameField.becomeFirstResponder()
        case usernameField:
            passwordField.becomeFirstResponder()
        case passwordField:
            confirmPasswordField.becomeFirstResponder()
        case confirmPasswordField:
            phoneField.becomeFirstResponder()
        case phoneField:
            phoneField.resignFirstResponder()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}
