# I expect the ./secrets.rb file to define a hash called SECRETS that has two keys:
#   :email_user
#   :email_pass
require './secrets.rb'
require './emailTemplate.rb'

require 'gmail'

require 'nokogiri'
require 'open-uri'
require 'sqlite3'

TO = 'eriq.augustine@gmail.com'

BASE_URL = 'http://dictionary.law.com'
BASE_QUERY_URL = 'http://dictionary.law.com/Default.aspx?selected='
SEARCH_STRING = '#panelWord'
DB = 'daily-tutor.sqlite'

START_NUMBER = 18
END_NUMBER = 2481
DAILY_COUNT = 5

def sendMail(subjectText, bodyHTML)
   Gmail.connect(SECRETS[:email_user], SECRETS[:email_pass]) {|gmail|
      gmail.deliver do
         to TO
         subject subjectText
         html_part do
            body bodyHTML
         end
      end
   }
end

def fetchWords()
   db = SQLite3::Database.new(DB)
   words = []

   while (words.size() < DAILY_COUNT)
      wordID = rand(START_NUMBER..END_NUMBER)

      query = 'SELECT COUNT(*) FROM UsedIDs WHERE id = ' + wordID.to_s()
      rows = db.execute(query)

      if (rows[0][0] != 0)
         # Already used.
         next
      end

      url = BASE_QUERY_URL + wordID.to_s()
      doc = Nokogiri::HTML(open(url))

      if (!doc)
         next
      end

      node = doc.css(SEARCH_STRING).first

      if (!node)
         next
      end

      # Rewrite any "See Also" links to be absolute instead of relative.
      node.css('span.seeAlso a').each{|val|
         val['href'] = BASE_URL + '/' + val['href']
      }

      insert = 'INSERT INTO UsedIDs VALUES (' + wordID.to_s() + ')'
      #TEST
      # db.execute(insert)

      # Replace a strange character they put after "see also" links with a comma and space.
      words << node.to_html.gsub(" ", ', ');
   end

   db.close()
   return words
end

words = fetchWords()
subject = 'Daily Tutor: ' + Time.now().strftime("%Y-%m-%d")
body = EMAIL_TEMPLATE.sub('%BODY%', words.join("\n"))

#TEST
#puts words.join("\n")
puts body
#sendMail(subject, words.join("\n"))
