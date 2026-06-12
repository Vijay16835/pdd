class User:
    def __init__(self, **kwargs):
        self.id = None
        self.firebase_uid = None       # Firebase UID — primary key for Google-auth users
        self.full_name = None
        self.email = None
        self.hashed_password = None
        self.is_verified = False
        self.otp_code = None
        self.otp_expiry = None
        self.auth_provider = "email"
        self.profile_image = None
        self.date_of_birth = None
        self.age = None
        self.created_at = None
        self.updated_at = None
        self.settings = None
        for k, v in kwargs.items():
            setattr(self, k, v)
