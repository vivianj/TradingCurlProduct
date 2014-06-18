require 'yaml'

def loadFile(file)
    content = YAML.load_file(file)
    puts content['email']['password']
end

loadFile('property.yml')
