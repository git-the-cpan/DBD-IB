create database "test.gdb" user "SYSDBA" password "masterkey";
create table SIMPLE (person_id integer not null, 
person varchar(50),
comment varchar(200),
primary key (person_id));
commit;
quit;
