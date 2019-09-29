##About

Running Run-DbOperations.ps1 will run any tsql scripts in a specified directory where the filename contains a version number higher than the database we will be running the operations against

##Testing

For testing purposes there is an included docker-compose.yaml, which will spin up a mysql v5.7 container so we can validate our script operations

        docker-compose up --build -d

##Example
.\Run-DbOperations.ps1 C:\sql\ScriptDir root ecs_test_db password
