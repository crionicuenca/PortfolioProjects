# import libraries
import pandas as pd
import requests
import re
from difflib import get_close_matches as match
from collections import Counter

# scrape fortune 500 page
URL = "https://fortune.com/ranking/fortune500/search/"
page = requests.get(URL).text.replace('\\u0026','&')

# split html according to each company
data = re.split('\[{"data":|,{"data":|\],"keywords"', page)
data.pop(0)
data.pop()
# data = data[:500] # first 500 companies
data = data[-500:] # last 500 companies

# initialize data frame and column headers
header = ['revenues','revenuePercentChange','profits','profitsPercentChange',
          'assets','marketValue','changeinRank1000','employees','sector',
          'industry','changeinRank500','name','rank','sfdc match1','sfdc match2']
df = pd.DataFrame(index=range(len(data)), columns=header)

# header names used to split metrics per company via html
header2 = [':"','"Revenue Percent Change":"',
           '"Profits \(\$M\)":"','"Profits Percent Change":"','"Assets \(\$M\)":"',
           '"Market Value \— as of March 31, 2023 \(\$M\)":"',
           '"Change in Rank \(Full 1000\)":"','"Employees":"','"Sector":"',
           '"Industry":"','"Change in Rank \(500 only\)":"','"name":"','"rank":',]
# header names used to check if metric value=0
header3 = ['', 'Revenue Percent Change', 'Profits ($M)', 'Profits Percent Change',
           'Assets ($M)', 'Market Value', 'Change in Rank (Full 1000)', 'Employees',
           'Sector','Industry','Change in Rank (500 only)', 'name', 'rank']

# keep only company data displayed in fortune 500 site
# populate list with data via for loop, then populate df using list
# initialize list (this will act as a middleman for df)
list = [*range(0,len(data))]
for j in range(0,len(header)-2):
    for i in range(0,len(data)):
        list[i] = data[i]
        # if header3 value isn't found in html, value=0
        if (list[i].find(header3[j]))==-1: list[i]=0
        # else, parse html for metric value and update df
        else:
            list[i] = re.sub('{"Revenues.*?'+header2[j],'', list[i])
            if j==header.index('rank'): list[i] = re.sub('\,.*?\/"}', '', list[i])
            else: list[i] = re.sub('\",.*?\/"}', '', list[i])
        df.iat[i,j] = list[i]

#-- MATCHING BELOW IS SLOW, SO COMMENT OUT IF YOU JUST WANT THE DATA FRAME

# import global ultimate parent names from sfdc report as list of strings
# csv is presorted according to arr then max count of accounts in sfdc
accounts = [str(i) for i in pd.read_csv('sfdc accounts.csv')['abm'].tolist()]

# match each company name to sfdc names according to full words found
for i in range(0,len(data)):
    # split sfdc company names into individual words
    sfdc_words = [s.replace(',', '').split() for s in accounts]
    # split df names and count frequency in sfdc list
    df_count = Counter(df.iat[i,11].lower().split())
    def match_score(j):
        sfdc_count = Counter(j)
        score = sum(df_count[k] for k in df_count if k in sfdc_count)
        return score
    scores = [match_score(words) for words in sfdc_words]
    # return first sfdc company with the max full words that match
    max_score = 0
    max_sfdc = 0
    for l, score in enumerate(scores):
        if score > max_score:
            max_score = score
            max_sfdc = l
    df.iat[i,13] = accounts[max_sfdc].title()

# fuzzy match each company name to sfdc names
for i in range(0,len(data)):
    df.iat[i,14] = match(df.iloc[i,11].lower(), accounts)[0].title()