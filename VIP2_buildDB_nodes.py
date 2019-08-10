import sqlite3

conn = sqlite3.connect('nodes.db')

c = conn.cursor()
c.execute('''CREATE TABLE names (
                        taxid INTEGER PRIMARY KEY,
                        name TEXT)''')

with open('scinames.dmp', 'r') as map_file:
        for line in map_file:
                line = line.split("|")
                taxid = line[0].strip()
                name = line[1].strip()
                c.execute ("INSERT INTO names VALUES (?,?)", (taxid, name))


c.execute('''CREATE TABLE nodes (
                        taxid INTEGER PRIMARY KEY,
                        parent_taxid INTEGER,
                        rank TEXT)''')

with open('nodes.dmp', 'r') as map_file:
        for line in map_file:
                line = line.split("|")
                taxid = line[0].strip()
                parent_taxid = line[1].strip()
                rank = line[2].strip()
                c.execute ("INSERT INTO nodes VALUES (?,?,?)", (taxid, parent_taxid, rank))

c.execute('''CREATE TABLE host (
                        taxid INTEGER PRIMARY KEY,
                        host TEXT)''')

with open('host.dmp', 'r') as map_file:
        for line in map_file:
                line = line.split("|")
                taxid = line[0].strip()
                host = line[1].strip()
                c.execute ("INSERT INTO host VALUES (?,?)", (taxid, host))

conn.commit()
conn.close()