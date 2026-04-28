import torch
import torchvision.models as models
import resnet 

model = resnet.ResNet(resnet.BasicBlock, [2, 2, 2, 2])
model.load_state_dict(torch.load('/workspace/projects/tutorials/PyTorch-ResNet18/files/pt_vehicle-color-classification_3.5/float/color_last_resnet18.pt', map_location='cpu'))

print(model)