-- LexGuard AI - PostgreSQL Database Schema
-- Optimized for AI Document Analysis and RAG

-- 1. Enable pgvector extension (for AI Chat RAG)
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Users Table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    auth_provider VARCHAR(50) DEFAULT 'email',
    profile_image VARCHAR(255),
    date_of_birth VARCHAR(50),
    age INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE otp_verifications (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    purpose VARCHAR(50) DEFAULT 'registration', -- 'registration' or 'password_reset'
    registration_data JSONB, -- Stores {full_name, hashed_password} temporarily
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. User Settings Table
CREATE TABLE user_settings (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    is_dark_mode BOOLEAN DEFAULT TRUE,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    selected_language VARCHAR(50) DEFAULT 'English',
    ai_model VARCHAR(100) DEFAULT 'LexGuard AI Engine v2.0',
    analysis_depth VARCHAR(50) DEFAULT 'Comprehensive',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Documents Table
CREATE TABLE documents (
    id VARCHAR(255) PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    path VARCHAR(255) NOT NULL,
    type VARCHAR(50),
    size_in_mb FLOAT,
    status VARCHAR(50) DEFAULT 'pending',
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Analysis Table
CREATE TABLE analysis (
    id SERIAL PRIMARY KEY,
    document_id VARCHAR(255) UNIQUE NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    risk_level VARCHAR(50),
    risk_score INTEGER,
    summary TEXT,
    ai_confidence FLOAT,
    parties JSONB, -- List of parties involved
    important_dates JSONB, -- Key dates extracted
    recommendations JSONB, -- AI-driven advice
    raw_analysis_data JSONB, -- Full AI response
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. Clauses Table (Extracted from Analysis)
CREATE TABLE clauses (
    id SERIAL PRIMARY KEY,
    document_id VARCHAR(255) NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    summary TEXT,
    risk_level VARCHAR(50),
    mitigation_advice TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. Chat History Table
CREATE TABLE chat_history (
    id SERIAL PRIMARY KEY,
    document_id VARCHAR(255) NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    response TEXT NOT NULL,
    -- Placeholder for vector embedding of the query for semantic search/RAG
    query_embedding vector(1536), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. Notifications Table
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50), -- 'analysis_complete', 'high_risk', etc.
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 9. Indexes for Optimization
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_analysis_document_id ON analysis(document_id);
CREATE INDEX idx_clauses_document_id ON clauses(document_id);
CREATE INDEX idx_chat_history_document_id ON chat_history(document_id);
CREATE INDEX idx_notifications_user_id_read ON notifications(user_id, is_read);
