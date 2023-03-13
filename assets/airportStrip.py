
# Python used for efficiency, as the airports.csv file is extremely long

def countryFilter(country):
    csv = open("airports.csv","r",encoding="UTF-8")
    newInfo=[]
    for line in csv:
        values = line.split(",")
        if values[8][1:3] == country and values[2]!='"closed"' and len(values[12]) == 6:
            print(values[12])
            newInfo.append(line)


    csv.close()
    newCSV = open(country+"Airports.csv","w+",encoding="UTF-8")
    for line in newInfo:
        newCSV.write(line)
    newCSV.close()

countryFilter("GB")

