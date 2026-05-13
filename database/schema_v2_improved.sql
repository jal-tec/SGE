-- ==============================================================
-- SISTEMA DE GESTÃO ESCOLAR (SGE) - VERSÃO 2 MELHORADA
-- FOCO: PERFORMANCE, API, WEB, SEGURANÇA E COMPLETUDE
-- ==============================================================
-- CHANGELOG:
-- - Adicionado tabela PROFESSORES com especialidade e titulação
-- - Novo modelo de ATRIBUIÇÕES (Professor-Turma)
-- - Tabelas separadas para AVALIACOES, PRESENCAS, AULAS
-- - Refatorado modelo FINANCEIRO com link a MATRICULAS
-- - Soft deletes para conformidade regulatória
-- - Audit trail básico
-- - Encarregados com tipos de relação
-- - Token de recuperação com expiração
-- - Constrains e índices aprimorados
-- ==============================================================

CREATE DATABASE IF NOT EXISTS sge_beta_pro 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE sge_beta_pro;

-- ==================== 1. TABELAS DE APOIO (DOMÍNIOS) ====================

CREATE TABLE niveis_acesso (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(30) NOT NULL UNIQUE,
    descricao VARCHAR(255),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Separação de domínios de status para type-safety
CREATE TABLE status_pessoas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(30) NOT NULL UNIQUE,
    descricao VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE status_matriculas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(30) NOT NULL UNIQUE,
    descricao VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE status_pagamentos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(30) NOT NULL UNIQUE,
    descricao VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE generos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(20) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE tipos_sanguineos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(10) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE tipos_relacao_encarregado (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(20) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE metodos_pagamento (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE tipos_titulacao (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ==================== 2. INFRAESTRUTURA DE CONTATO E SEGURANÇA ====================

CREATE TABLE moradas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    pais VARCHAR(50) DEFAULT 'Angola',
    provincia VARCHAR(50) DEFAULT 'Luanda',
    municipio VARCHAR(50) NOT NULL,
    bairro VARCHAR(50) NOT NULL,
    rua VARCHAR(100),
    casa_numero VARCHAR(20),
    complemento VARCHAR(200),
    coordenadas_gps VARCHAR(100),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_morada_municipio (municipio),
    INDEX idx_morada_bairro (bairro)
) ENGINE=InnoDB;

CREATE TABLE contactos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    telefone_principal VARCHAR(20) NOT NULL,
    telefone_alternativo VARCHAR(20),
    email_institucional VARCHAR(100) UNIQUE,
    email_pessoal VARCHAR(100),
    linkedin_url VARCHAR(255),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_contacto_email_inst (email_institucional),
    INDEX idx_contacto_telefone (telefone_principal)
) ENGINE=InnoDB;

-- ==================== 3. NÚCLEO: PESSOAS E USUÁRIOS ====================

CREATE TABLE pessoas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    nome_completo VARCHAR(150) NOT NULL,
    data_nascimento DATE NOT NULL,
    nif_bi VARCHAR(30) UNIQUE NOT NULL,
    genero_id INT,
    tipo_sanguineo_id INT,
    contacto_id INT,
    morada_id INT,
    status_id INT DEFAULT 1,
    foto_perfil_caminho VARCHAR(255),
    foto_perfil_tipo VARCHAR(20),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deletado_em TIMESTAMP NULL,
    FOREIGN KEY (genero_id) REFERENCES generos(id),
    FOREIGN KEY (tipo_sanguineo_id) REFERENCES tipos_sanguineos(id),
    FOREIGN KEY (contacto_id) REFERENCES contactos(id) ON DELETE SET NULL,
    FOREIGN KEY (morada_id) REFERENCES moradas(id) ON DELETE SET NULL,
    FOREIGN KEY (status_id) REFERENCES status_pessoas(id),
    INDEX idx_pessoa_nome (nome_completo),
    INDEX idx_pessoa_nif (nif_bi),
    INDEX idx_pessoa_deletado (deletado_em)
) ENGINE=InnoDB;

CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pessoa_id INT NOT NULL UNIQUE,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nivel_acesso_id INT NOT NULL,
    ultimo_login DATETIME,
    token_recuperacao VARCHAR(100),
    token_expira_em TIMESTAMP NULL,
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (pessoa_id) REFERENCES pessoas(id) ON DELETE CASCADE,
    FOREIGN KEY (nivel_acesso_id) REFERENCES niveis_acesso(id),
    INDEX idx_usuario_username (username),
    INDEX idx_usuario_ativo (ativo)
) ENGINE=InnoDB;

CREATE TABLE audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT,
    tabela VARCHAR(50) NOT NULL,
    registro_id INT NOT NULL,
    operacao ENUM('CREATE', 'UPDATE', 'DELETE') NOT NULL,
    dados_antigos JSON,
    dados_novos JSON,
    ip_address VARCHAR(45),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL,
    INDEX idx_audit_tabela (tabela),
    INDEX idx_audit_data (criado_em)
) ENGINE=InnoDB;

-- ==================== 4. ACADÊMICO E GESTÃO ====================

CREATE TABLE cursos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    nome VARCHAR(100) NOT NULL UNIQUE,
    sigla VARCHAR(10),
    descricao TEXT,
    duracao_semestres INT DEFAULT 2,
    valor_mensalidade DECIMAL(12,2) NOT NULL,
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deletado_em TIMESTAMP NULL,
    CONSTRAINT chk_duracao_positiva CHECK (duracao_semestres > 0),
    CONSTRAINT chk_mensalidade_positiva CHECK (valor_mensalidade > 0),
    INDEX idx_curso_ativo (ativo),
    INDEX idx_curso_sigla (sigla)
) ENGINE=InnoDB;

CREATE TABLE turmas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    codigo_turma VARCHAR(20) NOT NULL UNIQUE,
    curso_id INT NOT NULL,
    periodo ENUM('MANHÃ', 'TARDE', 'NOITE') NOT NULL,
    ano_letivo VARCHAR(9) NOT NULL,
    semestre INT DEFAULT 1,
    vagas_totais INT DEFAULT 30,
    status_id INT DEFAULT 1,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deletado_em TIMESTAMP NULL,
    FOREIGN KEY (curso_id) REFERENCES cursos(id) ON DELETE RESTRICT,
    FOREIGN KEY (status_id) REFERENCES status_matriculas(id),
    CONSTRAINT chk_vagas_positivas CHECK (vagas_totais > 0),
    CONSTRAINT chk_semestre_valido CHECK (semestre BETWEEN 1 AND 4),
    UNIQUE (codigo_turma, ano_letivo),
    INDEX idx_turma_ano_letivo (ano_letivo),
    INDEX idx_turma_curso (curso_id),
    INDEX idx_turma_deletado (deletado_em)
) ENGINE=InnoDB;

CREATE TABLE professores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    pessoa_id INT NOT NULL UNIQUE,
    numero_matricula VARCHAR(20) NOT NULL UNIQUE,
    especialidade VARCHAR(100),
    titulacao_id INT,
    bio TEXT,
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deletado_em TIMESTAMP NULL,
    FOREIGN KEY (pessoa_id) REFERENCES pessoas(id) ON DELETE CASCADE,
    FOREIGN KEY (titulacao_id) REFERENCES tipos_titulacao(id),
    INDEX idx_professor_especialidade (especialidade),
    INDEX idx_professor_ativo (ativo),
    INDEX idx_professor_deletado (deletado_em)
) ENGINE=InnoDB;

CREATE TABLE atribuicoes_turmas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    professor_id INT NOT NULL,
    turma_id INT NOT NULL,
    disciplina VARCHAR(100) NOT NULL,
    carga_horaria_total INT,
    data_inicio DATE NOT NULL,
    data_fim DATE,
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (professor_id) REFERENCES professores(id) ON DELETE CASCADE,
    FOREIGN KEY (turma_id) REFERENCES turmas(id) ON DELETE CASCADE,
    UNIQUE (professor_id, turma_id, disciplina),
    INDEX idx_atribuicao_professor (professor_id),
    INDEX idx_atribuicao_turma (turma_id),
    INDEX idx_atribuicao_ativo (ativo)
) ENGINE=InnoDB;

CREATE TABLE estudantes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    pessoa_id INT NOT NULL UNIQUE,
    numero_processo VARCHAR(20) NOT NULL UNIQUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deletado_em TIMESTAMP NULL,
    FOREIGN KEY (pessoa_id) REFERENCES pessoas(id) ON DELETE CASCADE,
    INDEX idx_estudante_numero_processo (numero_processo),
    INDEX idx_estudante_deletado (deletado_em)
) ENGINE=InnoDB;

CREATE TABLE encarregados (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    estudante_id INT NOT NULL,
    pessoa_id INT NOT NULL,
    tipo_relacao_id INT NOT NULL,
    prioridade_contacto INT DEFAULT 1,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (estudante_id) REFERENCES estudantes(id) ON DELETE CASCADE,
    FOREIGN KEY (pessoa_id) REFERENCES pessoas(id) ON DELETE CASCADE,
    FOREIGN KEY (tipo_relacao_id) REFERENCES tipos_relacao_encarregado(id),
    UNIQUE (estudante_id, pessoa_id),
    INDEX idx_encarregado_estudante (estudante_id),
    INDEX idx_encarregado_prioridade (prioridade_contacto)
) ENGINE=InnoDB;

CREATE TABLE matriculas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    estudante_id INT NOT NULL,
    turma_id INT NOT NULL,
    data_matricula DATE NOT NULL,
    status_id INT DEFAULT 1,
    data_conclusao DATE,
    nota_final DECIMAL(5,2),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deletado_em TIMESTAMP NULL,
    FOREIGN KEY (estudante_id) REFERENCES estudantes(id) ON DELETE CASCADE,
    FOREIGN KEY (turma_id) REFERENCES turmas(id) ON DELETE CASCADE,
    FOREIGN KEY (status_id) REFERENCES status_matriculas(id),
    UNIQUE (estudante_id, turma_id),
    INDEX idx_matricula_status (status_id),
    INDEX idx_matricula_data (data_matricula),
    INDEX idx_matricula_deletado (deletado_em)
) ENGINE=InnoDB;

-- ==================== 5. ACADÊMICO: AULAS, PRESENÇA E AVALIAÇÕES ====================

CREATE TABLE aulas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    atribuicao_turma_id INT NOT NULL,
    data_aula DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL,
    local VARCHAR(100),
    descricao TEXT,
    conteudo_abordado TEXT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (atribuicao_turma_id) REFERENCES atribuicoes_turmas(id) ON DELETE CASCADE,
    INDEX idx_aula_data (data_aula),
    INDEX idx_aula_atribuicao (atribuicao_turma_id)
) ENGINE=InnoDB;

CREATE TABLE presencas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    aula_id INT NOT NULL,
    estudante_id INT NOT NULL,
    presente BOOLEAN DEFAULT FALSE,
    justificada BOOLEAN DEFAULT FALSE,
    motivo_ausencia VARCHAR(255),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (aula_id) REFERENCES aulas(id) ON DELETE CASCADE,
    FOREIGN KEY (estudante_id) REFERENCES estudantes(id) ON DELETE CASCADE,
    UNIQUE (aula_id, estudante_id),
    INDEX idx_presenca_presente (presente),
    INDEX idx_presenca_estudante (estudante_id)
) ENGINE=InnoDB;

CREATE TABLE avaliacoes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    atribuicao_turma_id INT NOT NULL,
    titulo VARCHAR(100) NOT NULL,
    tipo ENUM('TESTE', 'EXAME', 'TRABALHO', 'PROJETO', 'PARTICIPACAO') DEFAULT 'TESTE',
    data_avaliacao DATE NOT NULL,
    peso_percentual DECIMAL(5,2) DEFAULT 0,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (atribuicao_turma_id) REFERENCES atribuicoes_turmas(id) ON DELETE CASCADE,
    CONSTRAINT chk_peso_valido CHECK (peso_percentual >= 0 AND peso_percentual <= 1),
    INDEX idx_avaliacao_data (data_avaliacao),
    INDEX idx_avaliacao_tipo (tipo)
) ENGINE=InnoDB;

CREATE TABLE notas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    avaliacao_id INT NOT NULL,
    estudante_id INT NOT NULL,
    valor_obtido DECIMAL(5,2),
    valor_maximo DECIMAL(5,2) DEFAULT 20,
    feedback VARCHAR(255),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (avaliacao_id) REFERENCES avaliacoes(id) ON DELETE CASCADE,
    FOREIGN KEY (estudante_id) REFERENCES estudantes(id) ON DELETE CASCADE,
    UNIQUE (avaliacao_id, estudante_id),
    CONSTRAINT chk_nota_valida CHECK (valor_obtido >= 0 AND valor_obtido <= valor_maximo),
    INDEX idx_nota_estudante (estudante_id)
) ENGINE=InnoDB;

-- ==================== 6. FINANCEIRO REFATORADO ====================

CREATE TABLE pagamentos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    referencia_bancaria VARCHAR(50) UNIQUE NOT NULL,
    matricula_id INT NOT NULL,
    periodo_ref VARCHAR(10) NOT NULL,
    valor_devido DECIMAL(12,2) NOT NULL,
    valor_pago DECIMAL(12,2) NOT NULL DEFAULT 0,
    data_vencimento DATE NOT NULL,
    data_pagamento TIMESTAMP,
    metodo_pagamento_id INT,
    comprovativo_url VARCHAR(255),
    status_id INT DEFAULT 3,
    observacoes TEXT,
    data_processamento TIMESTAMP,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (matricula_id) REFERENCES matriculas(id) ON DELETE RESTRICT,
    FOREIGN KEY (metodo_pagamento_id) REFERENCES metodos_pagamento(id),
    FOREIGN KEY (status_id) REFERENCES status_pagamentos(id),
    CONSTRAINT chk_valor_pago_positivo CHECK (valor_pago >= 0),
    CONSTRAINT chk_valor_devido_positivo CHECK (valor_devido > 0),
    CONSTRAINT chk_valor_pago_nao_excede CHECK (valor_pago <= valor_devido),
    UNIQUE (matricula_id, periodo_ref),
    INDEX idx_pagamento_matricula (matricula_id),
    INDEX idx_pagamento_status (status_id),
    INDEX idx_pagamento_vencimento (data_vencimento),
    INDEX idx_pagamento_data_pag (data_pagamento)
) ENGINE=InnoDB;

CREATE TABLE multas_atraso (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    pagamento_id INT NOT NULL,
    dias_atraso INT NOT NULL,
    percentual_multa DECIMAL(5,2) NOT NULL DEFAULT 5,
    valor_multa DECIMAL(12,2) NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pagamento_id) REFERENCES pagamentos(id) ON DELETE CASCADE,
    INDEX idx_multa_pagamento (pagamento_id)
) ENGINE=InnoDB;

-- ==================== 7. VIEWS PARA API ====================

CREATE VIEW view_perfil_estudante AS
SELECT 
    p.uuid AS pessoa_uuid,
    e.uuid AS estudante_uuid,
    p.nome_completo,
    e.numero_processo,
    c.nome AS curso,
    c.sigla AS sigla_curso,
    t.codigo_turma,
    t.periodo,
    t.ano_letivo,
    m.uuid AS matricula_uuid,
    sm.nome AS status_matricula,
    ct.email_institucional,
    ct.email_pessoal,
    ct.telefone_principal,
    m.data_matricula,
    m.data_conclusao,
    m.nota_final,
    COUNT(DISTINCT at.id) AS numero_disciplinas
FROM estudantes e
JOIN pessoas p ON e.pessoa_id = p.id AND p.deletado_em IS NULL
JOIN matriculas m ON e.id = m.estudante_id AND m.deletado_em IS NULL
JOIN turmas t ON m.turma_id = t.id AND t.deletado_em IS NULL
JOIN cursos c ON t.curso_id = c.id AND c.deletado_em IS NULL
JOIN status_matriculas sm ON m.status_id = sm.id
JOIN contactos ct ON p.contacto_id = ct.id
LEFT JOIN atribuicoes_turmas at ON t.id = at.turma_id AND at.ativo = TRUE
WHERE e.deletado_em IS NULL
GROUP BY e.id, m.id;

CREATE VIEW view_desempenho_estudante AS
SELECT 
    e.uuid AS estudante_uuid,
    p.nome_completo,
    at.disciplina,
    t.codigo_turma,
    COUNT(DISTINCT au.id) AS total_aulas,
    SUM(IF(pr.presente = TRUE, 1, 0)) AS aulas_presentes,
    ROUND(100.0 * SUM(IF(pr.presente = TRUE, 1, 0)) / COUNT(DISTINCT au.id), 2) AS percentual_presenca,
    ROUND(AVG(n.valor_obtido), 2) AS media_notas,
    MAX(n.valor_obtido) AS nota_maxima,
    MIN(n.valor_obtido) AS nota_minima
FROM estudantes e
JOIN pessoas p ON e.pessoa_id = p.id
JOIN matriculas m ON e.id = m.estudante_id
JOIN turmas t ON m.turma_id = t.id
JOIN atribuicoes_turmas at ON t.id = at.turma_id
LEFT JOIN aulas au ON at.id = au.atribuicao_turma_id
LEFT JOIN presencas pr ON au.id = pr.aula_id AND pr.estudante_id = e.id
LEFT JOIN notas n ON n.estudante_id = e.id
LEFT JOIN avaliacoes av ON n.avaliacao_id = av.id AND av.atribuicao_turma_id = at.id
WHERE e.deletado_em IS NULL AND m.deletado_em IS NULL
GROUP BY e.id, at.id;

CREATE VIEW view_status_financeiro_estudante AS
SELECT 
    e.uuid AS estudante_uuid,
    p.nome_completo,
    t.codigo_turma,
    SUM(CASE WHEN p_status.nome = 'VALIDADO' THEN pg.valor_pago ELSE 0 END) AS total_pago,
    SUM(pg.valor_devido) AS total_devido,
    SUM(pg.valor_devido) - SUM(CASE WHEN p_status.nome = 'VALIDADO' THEN pg.valor_pago ELSE 0 END) AS saldo_devedor,
    COUNT(DISTINCT pg.id) AS numero_parcelas,
    COUNT(DISTINCT CASE WHEN pg.data_vencimento < CURDATE() AND p_status.nome != 'VALIDADO' THEN pg.id END) AS parcelas_atrasadas
FROM estudantes e
JOIN pessoas p ON e.pessoa_id = p.id
JOIN matriculas m ON e.id = m.estudante_id
JOIN turmas t ON m.turma_id = t.id
JOIN pagamentos pg ON m.id = pg.matricula_id
JOIN status_pagamentos p_status ON pg.status_id = p_status.id
WHERE e.deletado_em IS NULL AND m.deletado_em IS NULL
GROUP BY e.id, m.id;

CREATE VIEW view_professor_turmas AS
SELECT 
    prof.uuid AS professor_uuid,
    pes.nome_completo AS nome_professor,
    pes.uuid AS pessoa_uuid,
    prof.especialidade,
    tt.nome AS titulacao,
    at.disciplina,
    t.codigo_turma,
    t.ano_letivo,
    t.periodo,
    c.nome AS curso,
    at.carga_horaria_total,
    at.data_inicio,
    at.data_fim,
    at.ativo
FROM professores prof
JOIN pessoas pes ON prof.pessoa_id = pes.id AND pes.deletado_em IS NULL
LEFT JOIN tipos_titulacao tt ON prof.titulacao_id = tt.id
JOIN atribuicoes_turmas at ON prof.id = at.professor_id AND at.ativo = TRUE
JOIN turmas t ON at.turma_id = t.id AND t.deletado_em IS NULL
JOIN cursos c ON t.curso_id = c.id AND c.deletado_em IS NULL
WHERE prof.deletado_em IS NULL;

CREATE VIEW view_relatorio_presenca_turma AS
SELECT 
    t.codigo_turma,
    t.ano_letivo,
    au.data_aula,
    prof.nome_completo AS professor,
    at.disciplina,
    COUNT(DISTINCT pr.estudante_id) AS total_inscritos,
    SUM(IF(pr.presente = TRUE, 1, 0)) AS presentes,
    SUM(IF(pr.presente = FALSE AND pr.justificada = TRUE, 1, 0)) AS ausencias_justificadas,
    SUM(IF(pr.presente = FALSE AND pr.justificada = FALSE, 1, 0)) AS ausencias_injustificadas,
    ROUND(100.0 * SUM(IF(pr.presente = TRUE, 1, 0)) / COUNT(DISTINCT pr.estudante_id), 2) AS taxa_presenca
FROM aulas au
JOIN atribuicoes_turmas at ON au.atribuicao_turma_id = at.id
JOIN turmas t ON at.turma_id = t.id
JOIN professores prof ON at.professor_id = prof.id
LEFT JOIN presencas pr ON au.id = pr.aula_id
GROUP BY au.id, t.id;

-- ==================== 8. ÍNDICES ESTRATÉGICOS ====================

CREATE INDEX idx_pessoas_global_search ON pessoas (nome_completo, nif_bi);
CREATE INDEX idx_contactos_global ON contactos (email_institucional, telefone_principal);
CREATE INDEX idx_pagamentos_data_range ON pagamentos (data_vencimento, data_pagamento);
CREATE INDEX idx_presencas_data ON presencas (criado_em);
CREATE INDEX idx_notas_estudante_disciplina ON notas (estudante_id);
CREATE INDEX idx_atribuicao_professor_ativo ON atribuicoes_turmas (professor_id, ativo);
CREATE INDEX idx_aulas_periodo ON aulas (data_aula, atribuicao_turma_id);

-- ==================== 9. DADOS INICIAIS (SEED DATA) ====================

INSERT INTO niveis_acesso (nome, descricao) VALUES
('ADMIN', 'Administrador do sistema com acesso total'),
('PROFESSOR', 'Professor com acesso ao portal de professores'),
('ESTUDANTE', 'Estudante com acesso a seu portal'),
('FINANCEIRO', 'Funcionário do departamento financeiro'),
('ENCARREGADO', 'Encarregado de estudante');

INSERT INTO status_pessoas (nome, descricao) VALUES
('ATIVO', 'Pessoa ativa no sistema'),
('INATIVO', 'Pessoa inativa'),
('SUSPENSO', 'Acesso suspenso temporariamente'),
('TRANCADO', 'Acesso bloqueado');

INSERT INTO status_matriculas (nome, descricao) VALUES
('CONFIRMADA', 'Matrícula confirmada e ativa'),
('PENDENTE', 'Matrícula aguardando confirmação'),
('CANCELADA', 'Matrícula cancelada'),
('TRANCADA', 'Matrícula trancada temporariamente'),
('CONCLUIDA', 'Curso concluído');

INSERT INTO status_pagamentos (nome, descricao) VALUES
('VALIDADO', 'Pagamento validado e confirmado'),
('AGUARDANDO', 'Pagamento aguardando validação'),
('REJEITADO', 'Pagamento rejeitado'),
('PROCESSANDO', 'Pagamento sendo processado'),
('EXPIRADO', 'Prazo de pagamento expirou');

INSERT INTO generos (nome) VALUES ('Masculino'), ('Feminino'), ('Outro');

INSERT INTO tipos_sanguineos (nome) VALUES 
('O+'), ('O-'), ('A+'), ('A-'), ('B+'), ('B-'), ('AB+'), ('AB-');

INSERT INTO tipos_relacao_encarregado (nome) VALUES 
('PAI'), ('MAE'), ('TUTOR'), ('RESPONSAVEL'), ('AVO'), ('OUTRO');

INSERT INTO metodos_pagamento (nome) VALUES 
('TPA'), ('TRANSFERENCIA'), ('DEPOSITO'), ('CASH'), ('CHEQUE'), ('MBWAY');

INSERT INTO tipos_titulacao (nome) VALUES 
('LICENCIATURA'), ('MESTRADO'), ('DOUTORADO'), ('POS_DOUTORADO'), ('TECNICO');

-- ==================== FIM DO SCHEMA ====================
