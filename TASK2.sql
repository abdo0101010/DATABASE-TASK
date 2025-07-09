

-- جدول EMPLOYEE
CREATE TABLE EMPLOYEE (
    SSN VARCHAR(14) PRIMARY KEY,
    FNAME VARCHAR(50) NOT NULL,
    LNAME VARCHAR(50) NOT NULL,
    BIRTHDATE DATE NOT NULL,
    GENDER CHAR(1) NOT NULL CHECK (GENDER IN ('M', 'F')),
    DNUM INT NULL,
    SUPERVISOR_SSN VARCHAR(14) NULL,
    HireDate DATE DEFAULT GETDATE()
);

-- جدول DEPARTMENT (MANAGER_SSN يقبل NULL في الأول)
CREATE TABLE DEPARTMENT (
    DNUM INT PRIMARY KEY,
    DNAME VARCHAR(50) NOT NULL UNIQUE,
    LOCATION NVARCHAR(MAX),
    MANAGER_SSN VARCHAR(14) NULL,
    MANAGER_HIREDATE DATE NOT NULL
);

-- جدول PROJECT
CREATE TABLE PROJECT (
    PNUMBER INT PRIMARY KEY,
    PNAME VARCHAR(50) NOT NULL,
    LOCATION NVARCHAR(MAX),
    DNUM INT NOT NULL
);

-- جدول DEPENDENT
CREATE TABLE DEPENDENT (
    DEPENDENT_NAME VARCHAR(50),
    ESSN VARCHAR(14),
    GENDER CHAR(1) NOT NULL CHECK (GENDER IN ('M', 'F')),
    BIRTHDATE DATE,
    PRIMARY KEY (DEPENDENT_NAME, ESSN),
    FOREIGN KEY (ESSN) REFERENCES EMPLOYEE(SSN)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- جدول WORKS_ON
CREATE TABLE WORKS_ON (
    SSN VARCHAR(14),
    PNUMBER INT,
    HOURS INT DEFAULT 0 CHECK (HOURS >= 0),
    PRIMARY KEY (SSN, PNUMBER),
    FOREIGN KEY (SSN) REFERENCES EMPLOYEE(SSN)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    FOREIGN KEY (PNUMBER) REFERENCES PROJECT(PNUMBER)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);

-- ============================================
-- إضافة العلاقات
-- ============================================

ALTER TABLE EMPLOYEE
ADD CONSTRAINT FK_EMP_DEPT
FOREIGN KEY (DNUM) REFERENCES DEPARTMENT(DNUM)
    ON DELETE SET NULL
    ON UPDATE CASCADE;

ALTER TABLE DEPARTMENT
ADD CONSTRAINT FK_DEPT_MANAGER
FOREIGN KEY (MANAGER_SSN) REFERENCES EMPLOYEE(SSN)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE PROJECT
ADD CONSTRAINT FK_PROJECT_DEPT
FOREIGN KEY (DNUM) REFERENCES DEPARTMENT(DNUM)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

-- ============================================
-- إدخال البيانات بالترتيب الصحيح
-- ============================================

-- 1) إدخال أقسام بدون MANAGER_SSN
INSERT INTO DEPARTMENT (DNUM, DNAME, LOCATION, MANAGER_SSN, MANAGER_HIREDATE)
VALUES
(1, 'HR', 'Cairo', NULL, '2010-01-01'),
(2, 'IT', 'Alexandria', NULL, '2012-05-01'),
(3, 'Finance', 'Giza', NULL, '2015-09-01');

-- 2) إدخال الموظفين
INSERT INTO EMPLOYEE (SSN, FNAME, LNAME, BIRTHDATE, GENDER, DNUM)
VALUES
('1001', 'Ali', 'Hassan', '1990-01-01', 'M', 1),
('1002', 'Sara', 'Mahmoud', '1985-02-15', 'F', 2),
('1003', 'Omar', 'Youssef', '1992-03-20', 'M', 3),
('1004', 'Mona', 'Adel', '1988-05-05', 'F', 2),
('1005', 'Khaled', 'Mostafa', '1995-07-10', 'M', 1);

-- 3) تحديث MANAGER_SSN للأقسام
UPDATE DEPARTMENT SET MANAGER_SSN = '1001' WHERE DNUM = 1;
UPDATE DEPARTMENT SET MANAGER_SSN = '1002' WHERE DNUM = 2;
UPDATE DEPARTMENT SET MANAGER_SSN = '1003' WHERE DNUM = 3;

-- 4) إضافة المشاريع
INSERT INTO PROJECT (PNUMBER, PNAME, LOCATION, DNUM)
VALUES
(101, 'Website Redesign', 'Cairo', 2),
(102, 'Payroll System', 'Giza', 3),
(103, 'Recruitment Drive', 'Alexandria', 1);

-- 5) إضافة WORKS_ON
INSERT INTO WORKS_ON (SSN, PNUMBER, HOURS)
VALUES
('1001', 101, 20),
('1002', 101, 25),
('1003', 102, 15),
('1004', 103, 30),
('1005', 101, 10);

-- 6) إضافة DEPENDENT
INSERT INTO DEPENDENT (DEPENDENT_NAME, ESSN, GENDER, BIRTHDATE)
VALUES
('Ahmed', '1001', 'M', '2010-01-01'),
('Layla', '1002', 'F', '2012-03-03');

-- ============================================
-- تعديل وإزالة بيانات للتجربة
-- ============================================

-- تحديث موظف
UPDATE EMPLOYEE SET DNUM = 3 WHERE SSN = '1005';

-- حذف Dependent
DELETE FROM DEPENDENT WHERE DEPENDENT_NAME = 'Ahmed';

-- ============================================
-- استعلامات بسيطة
-- ============================================

-- كل الموظفين في قسم معين
SELECT *
FROM EMPLOYEE
WHERE DNUM = 2;

-- الموظفين والمشاريع وساعات العمل
SELECT 
    E.FNAME,
    E.LNAME,
    P.PNAME,
    W.HOURS
FROM WORKS_ON W
JOIN EMPLOYEE E ON W.SSN = E.SSN
JOIN PROJECT P ON W.PNUMBER = P.PNUMBER;
