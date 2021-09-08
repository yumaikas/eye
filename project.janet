(declare-project :name "eye" 
                 :description "eye watches your files, and re-runs a command when they change"
                 :author "Andrew Owen <yumaikas94@gmail.com"
                 :url "https://github.com/yumaikas/eye"
                 :dependencies ["path"])

(declare-executable :name "eye" :entry "eye.janet")
