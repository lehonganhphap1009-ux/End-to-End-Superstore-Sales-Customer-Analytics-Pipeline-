BULK INSERT superstore
FROM 'D:\project\projec_2\Sample - Superstore.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A',
    DATAFILETYPE = 'char'
);