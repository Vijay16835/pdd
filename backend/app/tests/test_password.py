import unittest
import sys
import os

# Add backend directory to PYTHONPATH
backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from pydantic import ValidationError
from app.schemas.auth import UserCreate, UserLogin, ResetPassword, ChangePassword
from app.core.security import get_password_hash, verify_password

class TestPasswordValidation(unittest.TestCase):

    def test_valid_passwords_schema(self):
        # 1. Test standard 8-character password "10981098"
        try:
            user_in = UserCreate(full_name="Test User", email="test@example.com", password="10981098", date_of_birth="2000-01-01")
            self.assertEqual(user_in.password, "10981098")
        except ValidationError:
            self.fail("UserCreate raised ValidationError for '10981098'")

        # 2. Test alphanumeric with symbols password "Password@123"
        try:
            user_in = UserCreate(full_name="Test User", email="test@example.com", password="Password@123", date_of_birth="2000-01-01")
            self.assertEqual(user_in.password, "Password@123")
        except ValidationError:
            self.fail("UserCreate raised ValidationError for 'Password@123'")

        # 3. Test exactly 72 bytes password
        pwd_72 = "a" * 72
        try:
            user_in = UserCreate(full_name="Test User", email="test@example.com", password=pwd_72, date_of_birth="2000-01-01")
            self.assertEqual(user_in.password, pwd_72)
        except ValidationError:
            self.fail("UserCreate raised ValidationError for password of exactly 72 bytes")

    def test_invalid_password_schema_length(self):
        # 4. Test password exceeding 72 bytes (73 characters/bytes)
        pwd_73 = "a" * 73
        with self.assertRaises(ValidationError) as ctx:
            UserCreate(full_name="Test User", email="test@example.com", password=pwd_73, date_of_birth="2000-01-01")
        self.assertIn("Password cannot be longer than 72 bytes", str(ctx.exception))

        # 5. Test UserLogin validation
        with self.assertRaises(ValidationError) as ctx:
            UserLogin(email="test@example.com", password=pwd_73)
        self.assertIn("Password cannot be longer than 72 bytes", str(ctx.exception))

        # 6. Test ResetPassword validation
        with self.assertRaises(ValidationError) as ctx:
            ResetPassword(email="test@example.com", otp="123456", new_password=pwd_73)
        self.assertIn("Password cannot be longer than 72 bytes", str(ctx.exception))

        # 7. Test ChangePassword validation
        with self.assertRaises(ValidationError) as ctx:
            ChangePassword(current_password=pwd_73, new_password="safe_password")
        self.assertIn("Password cannot be longer than 72 bytes", str(ctx.exception))

        with self.assertRaises(ValidationError) as ctx:
            ChangePassword(current_password="safe_password", new_password=pwd_73)
        self.assertIn("Password cannot be longer than 72 bytes", str(ctx.exception))

        # 7.1. Test passwords shorter than 8 characters
        pwd_short = "short"
        with self.assertRaises(ValidationError) as ctx:
            UserCreate(full_name="Test User", email="test@example.com", password=pwd_short, date_of_birth="2000-01-01")
        self.assertIn("Password must be at least 8 characters long", str(ctx.exception))

        with self.assertRaises(ValidationError) as ctx:
            UserLogin(email="test@example.com", password=pwd_short)
        self.assertIn("Password must be at least 8 characters long", str(ctx.exception))

        with self.assertRaises(ValidationError) as ctx:
            ResetPassword(email="test@example.com", otp="123456", new_password=pwd_short)
        self.assertIn("Password must be at least 8 characters long", str(ctx.exception))

        # 8. Test UTF-8 byte length vs character length
        # Russian character 'ш' takes 2 bytes. 37 * 2 = 74 bytes, but only 37 characters.
        pwd_non_ascii = "ш" * 37
        self.assertEqual(len(pwd_non_ascii), 37)
        self.assertEqual(len(pwd_non_ascii.encode("utf-8")), 74)

        with self.assertRaises(ValidationError) as ctx:
            UserCreate(full_name="Test User", email="test@example.com", password=pwd_non_ascii, date_of_birth="2000-01-01")
        self.assertIn("Password cannot be longer than 72 bytes", str(ctx.exception))

    def test_security_functions(self):
        # 9. Test get_password_hash and verify_password with valid passwords
        pwd1 = "10981098"
        pwd2 = "Password@123"

        hash1 = get_password_hash(pwd1)
        hash2 = get_password_hash(pwd2)

        self.assertTrue(verify_password(pwd1, hash1))
        self.assertTrue(verify_password(pwd2, hash2))
        self.assertFalse(verify_password(pwd1, hash2))

        # 10. Test security functions with > 72 bytes password
        pwd_73 = "a" * 73
        with self.assertRaises(ValueError) as ctx:
            get_password_hash(pwd_73)
        self.assertEqual(str(ctx.exception), "Password cannot be longer than 72 bytes")

        # 11. Test verify_password returns False directly for > 72 bytes input instead of raising ValueError
        self.assertFalse(verify_password(pwd_73, hash1))

if __name__ == "__main__":
    unittest.main()
