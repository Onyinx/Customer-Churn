 DROP TABLE IF EXISTS Transaction_History CASCADE;
 DROP TABLE IF EXISTS Customer_Service CASCADE;
 DROP TABLE IF EXISTS Online_Activity CASCADE; 
 DROP TABLE IF EXISTS Customer_Demographics CASCADE;

 CREATE TABLE Customer_Demographics (
    CustomerID      INT PRIMARY KEY,
    Age             INT,
    AgeGroup        VARCHAR(20),
    Gender          VARCHAR(10),
    MaritalStatus   VARCHAR(20),
    ChurnStatus     VARCHAR(3),
    IncomeLevel     VARCHAR(10)
);



CREATE TABLE Online_Activity (
    CustomerID      INT,
    ActivityYear    INT,
    Season          VARCHAR(10),
    ActivityMonth   VARCHAR(10),
    ActivityDay     VARCHAR(10),
    ActivityDate    INT,
    DayGroup        VARCHAR(10),
    LoginFrequency  INT,
    FrequencyRisk   VARCHAR(10),
    ServiceUsage    VARCHAR(50),
    FOREIGN KEY (CustomerID) REFERENCES Customer_Demographics(CustomerID)
);


CREATE TABLE Customer_Service (
    CustomerID       INT,
    InteractionID    INT,
    ServiceYear      INT,
    Season           VARCHAR(10),
    ServiceMonth     VARCHAR(10),
    ServiceDay       VARCHAR(10),
    ServiceDate      INT,
    DayGroup         VARCHAR(10),
    InteractionType  VARCHAR(50),
    ResolutionStatus VARCHAR(20),
    FOREIGN KEY (CustomerID) REFERENCES Customer_Demographics(CustomerID)
);

CREATE TABLE Transaction_History (
    CustomerID      INT,
    TransactionID   INT,
    TxnYear         INT,
    Season          VARCHAR(10),
    TxnMonth        VARCHAR(10),
    TxnDay          VARCHAR(10),
    TxnDate         INT,
    DayGroup        VARCHAR(10),
    AmountSpent     DECIMAL(10,2),
    ProductCategory VARCHAR(50),
    FOREIGN KEY (CustomerID) REFERENCES Customer_Demographics(CustomerID)
);


/* =========================================================================
   Q1 — Churn rate by login-frequency-risk band
   
   ========================================================================= */
SELECT
    oa.FrequencyRisk,
    COUNT(*)                                             
	AS customers,
    SUM(CASE WHEN cd.ChurnStatus = 'YES' THEN 1 ELSE 0 END)          
	AS churned,
    ROUND(100.0 * SUM(CASE WHEN cd.ChurnStatus = 'YES'
	THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                 
		  AS churn_rate_pct
FROM Online_Activity oa
JOIN Customer_Demographics cd ON cd.CustomerID = oa.CustomerID
GROUP BY oa.FrequencyRisk
ORDER BY churn_rate_pct DESC;


/* =========================================================================
   Q2 — Retention watchlist: customers currently in the LOW frequency-risk
   band (the segment proven to churn ~2x the baseline rate)
   ========================================================================= */
SELECT
    cd.CustomerID,
    cd.AgeGroup,
    cd.Gender,
    cd.MaritalStatus,
    cd.IncomeLevel,
    oa.LoginFrequency,
    oa.FrequencyRisk,
    cd.ChurnStatus         -- kept for validation; exclude before sending to the business team
FROM Online_Activity oa
JOIN Customer_Demographics cd ON cd.CustomerID = oa.CustomerID
WHERE oa.FrequencyRisk = 'LOW'
ORDER BY oa.LoginFrequency ASC;


/* =========================================================================
   Q3 — Churn rate: Marital Status x Income Level.
   ========================================================================= */
SELECT
    MaritalStatus,
    ROUND(100.0 * SUM(CASE WHEN IncomeLevel = 'High'   AND ChurnStatus = 'YES' THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN IncomeLevel = 'High'   THEN 1 ELSE 0 END), 0), 1) AS high_income_churn_pct,
    ROUND(100.0 * SUM(CASE WHEN IncomeLevel = 'Medium' AND ChurnStatus = 'YES' THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN IncomeLevel = 'Medium' THEN 1 ELSE 0 END), 0), 1) AS medium_income_churn_pct,
    ROUND(100.0 * SUM(CASE WHEN IncomeLevel = 'Low'    AND ChurnStatus = 'YES' THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN IncomeLevel = 'Low'    THEN 1 ELSE 0 END), 0), 1) AS low_income_churn_pct
FROM Customer_Demographics
GROUP BY MaritalStatus
ORDER BY MaritalStatus;


/* =========================================================================
   Q4 — churn drivers (service resolution, spend)
   Included to show what was tested and excluded, not just what "worked"
   ========================================================================= */
SELECT
    cs.ResolutionStatus,
    COUNT(*)                                               
	AS interactions,
    ROUND(100.0 * SUM(CASE WHEN cd.ChurnStatus = 'YES' 
	THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                   
		  AS churn_rate_pct
FROM Customer_Service cs
JOIN Customer_Demographics cd ON cd.CustomerID = cs.CustomerID
GROUP BY cs.ResolutionStatus;

-- Average spend: churned vs retained (finding: churned customers spend slightly MORE, not less)
SELECT
    cd.ChurnStatus,
    ROUND(AVG(th.AmountSpent), 2) AS avg_amount_spent,
    COUNT(*)                      AS transactions
FROM Transaction_History th
JOIN Customer_Demographics cd ON cd.CustomerID = th.CustomerID
GROUP BY cd.ChurnStatus;
