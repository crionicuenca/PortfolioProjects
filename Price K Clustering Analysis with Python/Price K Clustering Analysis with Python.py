# import libraries (might need to pip install first)
import pandas as pd
import numpy as np
import sklearn
import matplotlib.pyplot as plt
from sklearn.metrics import silhouette_score
from kmodes import kprototypes
from kmodes.kmodes import KModes

#-- KPROTOTYPES CLUSTERING (NUMERICAL & CATEGORICAL DATA)

# initialize dataframes and split numerical and categorical data
data = pd.read_csv('pricing data v5.csv')
data_cat = data.select_dtypes(include='object')
data_num_unscaled = data.select_dtypes(exclude='object')
data_num_scaled = data.select_dtypes(exclude='object')

# scale numerical data via MinMaxScaler
scaler = sklearn.preprocessing.MinMaxScaler()
for i in data_num_scaled.columns:
    data_num_scaled.loc[:,i] = scaler.fit_transform(
        np.array(data_num_scaled[i]).reshape(-1, 1))
data = pd.concat([data_cat, data_num_scaled], axis=1)
cat_col = [*range(0,len(data_cat.columns))]

# zeros = []
# for q in range(0,len(data)):
#     if data.loc[q,'ContractTotal']==0: zeros.append(q)
# data = data.drop(index=zeros)
# clusters['ContractLineItem']=data['ContractLineItem']
# data = data.drop(columns=['ContractLineItem','CompanySegmentAtClose'])

# determine optimal k via silhouette method
def mixed_distance(a,b,categorical=None, alpha=0.01):
    if categorical is None:
        num_score=kprototypes.euclidean_dissim(a,b)
        return num_score
    else:
        cat_index=categorical
        a_cat=[]
        b_cat=[]
        for index in cat_index:
            a_cat.append(a[index])
            b_cat.append(b[index])
        a_num=[]
        b_num=[]
        l=len(a)
        for index in range(l):
            if index not in cat_index:
                a_num.append(a[index])
                b_num.append(b[index])
                
        a_cat=np.array(a_cat).reshape(1,-1)
        a_num=np.array(a_num).reshape(1,-1)
        b_cat=np.array(b_cat).reshape(1,-1)
        b_num=np.array(b_num).reshape(1,-1)
        cat_score=kprototypes.matching_dissim(a_cat,b_cat)
        num_score=kprototypes.euclidean_dissim(a_num,b_num)
        return cat_score+num_score*alpha
def dm_prototypes(dataset,categorical=None,alpha=0.1):
    # if the input dataset is a dataframe, we take out the values as a numpy
    # if the input dataset is a numpy array, we use it as is
    if type(dataset).__name__=='DataFrame':
        dataset=dataset.values    
    lenDataset=len(dataset)
    distance_matrix=np.zeros(lenDataset*lenDataset).reshape(lenDataset,lenDataset)
    for i in range(lenDataset):
        for j in range(lenDataset):
            x1= dataset[i]
            x2= dataset[j]
            distance=mixed_distance(x1, x2,categorical=categorical,alpha=alpha)
            distance_matrix[i][j]=distance
            distance_matrix[j][i]=distance
    return distance_matrix
distance_matrix=dm_prototypes(data,categorical=cat_col,alpha=0.1)
silhouette_scores = dict()
for k in range(10,31):
    untrained_model = kprototypes.KPrototypes(n_clusters=k, init='Cao')
    trained_model = untrained_model.fit(data.dropna(), categorical=cat_col)
    cluster_labels = trained_model.labels_
    score = silhouette_score(distance_matrix,cluster_labels,metric="precomputed")
    silhouette_scores[k] = score
silhouette_scores = list(silhouette_scores.values())
plt.rcParams['figure.dpi']=500
plt.plot(range(10,31),silhouette_scores,'x-')
plt.xlabel('k'); plt.ylabel('Silhouette Score'); plt.show()
print('Optimal k = '+str(silhouette_scores.index(max(silhouette_scores))+10))

# plot price histogram
fig = plt.figure()
fig, axs = plt.subplots(4,3,figsize=(9,9))
for i in range(0,k):
    plot = data[data['cluster']==i]
    values,bins,bars = axs[row[i]][col[i]].hist(plot[data_price.columns[c]], edgecolor='white')
    axs[row[i]][col[i]].bar_label(bars)
    axs[row[i]][col[i]].margins(x=0.01, y=0.1)
    axs[row[i]][col[i]].set_title('Cluster '+str(i))
fig.tight_layout(pad=4)
fig.add_subplot(111, frameon=False)
plt.tick_params(labelcolor='none',which='both',top=False,bottom=False,left=False,right=False)
plt.xlabel(data_price.columns[c], size=6)
plt.ylabel('Count', size=6)
plt.show()
            
# run 3 iterations of clustering
for r in range(1,4):
    # combine num and cat data then perform kprototypes clustering
    k=10; kproto = kprototypes.KPrototypes(n_clusters=k, init='Cao')
    data['cluster'] = kproto.fit_predict(data,categorical=cat_col)
    data = data.drop(list(data)[len(data_cat.columns):(len(data)-1)], axis=1)
    clusterCount = data['cluster'].value_counts().to_frame().sort_index()
    
    # split and pivot product and segment data
    data_product = data.iloc[:,[*range(0,35),38]]
    data_product = pd.melt(data_product, id_vars=['cluster'],var_name='Product',value_name='Count')
    data_product = data_product[data_product.Count != 0].reset_index().drop(columns=['index','Count'])
    data_segment = data.iloc[:,[*range(35,38),38]]
    data_segment = pd.melt(data_segment, id_vars=['cluster'],var_name='Segment',value_name='Count')
    data_segment = data_segment[data_segment.Count != 0].reset_index().drop(columns=['index','Count'])

    # plot bar graphs of counts for categorical fields
    row = [0,0,1,1,2,2,3,3,4,4]
    col = [0,1,0,1,0,1,0,1,0,1]
    temp = [10,11,12,12,12,12,12,12,12,12]
    plt.rcParams['figure.dpi']=500
    fig = plt.figure()
    fig, axs = plt.subplots(5,2,figsize=(12,25))
    for i in range(0,10):
        plot = data_product[data_product['cluster']==i]
        plot = plot['Product'].value_counts().to_frame().reset_index()
        bars = axs[row[i]][col[i]].barh(plot[plot.columns[0]], plot[plot.columns[1]])
        axs[row[i]][col[i]].bar_label(bars, padding=2)
        axs[row[i]][col[i]].margins(x=0.15, y=0.01)
        axs[row[i]][col[i]].set_title('Iteration '+str(r)+' Cluster '+str(i)+' - '+
                                      str(clusterCount.iloc[i,0])+' Contracts')
    fig.tight_layout(pad=2)
    plt.show()
    fig = plt.figure()
    fig, axs = plt.subplots(5,2,figsize=(12,25))
    for i in range(0,10):
        plot = data_product[data_product['cluster']==temp[i]]
        plot = plot['Product'].value_counts().to_frame().reset_index()
        bars = axs[row[i]][col[i]].barh(plot[plot.columns[0]], plot[plot.columns[1]])
        axs[row[i]][col[i]].bar_label(bars, padding=2)
        axs[row[i]][col[i]].margins(x=0.15, y=0.01)
        axs[row[i]][col[i]].set_title('Iteration '+str(r)+' Cluster '+str(temp[i])+' - '+
                                      str(clusterCount.iloc[temp[i],0])+' Contracts')
    fig.tight_layout(pad=2)
    plt.show()


###############################################################################

#-- KMODES CLUSTERING (CATEGORICAL DATA ONLY)

# # read data
# data = pd.read_csv('pricing data v4.csv')#.iloc[:,:-3]

# # determine optimal k via elbow method
# cost = []
# for k in list(range(1,30)):
#     kmode = KModes(n_clusters=k, init="random", n_init=5, verbose=1)
#     kmode.fit_predict(data)
#     cost.append(kmode.cost_)
# plt.plot(range(1,30), cost, 'x-')
# plt.xlabel('k'); plt.ylabel('Cost')
# plt.show()

# # determine optimal k via silhouette method
# def create_dm(dataset):
#     #if the input dataset is a dataframe, we take out the values as a numpy. 
#     #If the input dataset is a numpy array, we use it as is.
#     if type(dataset).__name__=='DataFrame':
#         dataset=dataset.values    
#     lenDataset=len(dataset)
#     distance_matrix=np.zeros(lenDataset*lenDataset).reshape(lenDataset,lenDataset)
#     for i in range(lenDataset):
#         for j in range(lenDataset):
#             x1= dataset[i].reshape(1,-1)
#             x2= dataset[j].reshape(1,-1)
#             distance=kprototypes.matching_dissim(x1, x2)
#             distance_matrix[i][j]=distance
#             distance_matrix[j][i]=distance
#     return distance_matrix
# silhouette_scores = dict()
# distance_matrix=create_dm(data)
# for k in range(7,21):
#     untrained_model = KModes(n_clusters=k, n_init=5)
#     trained_model = untrained_model.fit(data)
#     cluster_labels = trained_model.labels_
#     score=silhouette_score(distance_matrix,cluster_labels,metric="precomputed")
#     silhouette_scores[k]=score
# silhouette_scores = list(silhouette_scores.values())
# plt.rcParams['figure.dpi']=500
# plt.plot(range(7,21),silhouette_scores,'x-')
# plt.xlabel('k'); plt.ylabel('Silhouette Score'); plt.show()
# print('Optimal k = '+str(silhouette_scores.index(max(silhouette_scores))+7))

# # run 3 iterations of clustering
# for r in range(1,4):
#     k=13 # perform kmodes and store results
#     kmode = KModes(n_clusters=k, init="random", n_init=5, verbose=1)
#     data['cluster'] = kmode.fit_predict(data)
#     clusterCount = data['cluster'].value_counts().to_frame().sort_index()
    
#     # split and pivot product and segment data
#     data_product = data.iloc[:,[*range(0,35),38]]
#     data_product = pd.melt(data_product, id_vars=['cluster'],var_name='Product',value_name='Count')
#     data_product = data_product[data_product.Count != 0].reset_index().drop(columns=['index','Count'])
#     data_segment = data.iloc[:,[*range(35,38),38]]
#     data_segment = pd.melt(data_segment, id_vars=['cluster'],var_name='Segment',value_name='Count')
#     data_segment = data_segment[data_segment.Count != 0].reset_index().drop(columns=['index','Count'])

#     # plot bar graphs of counts for categorical fields
#     row = [0,0,1,1,2,2,3,3,4,4]
#     col = [0,1,0,1,0,1,0,1,0,1]
#     temp = [10,11,12,12,12,12,12,12,12,12]
#     plt.rcParams['figure.dpi']=500
#     fig = plt.figure()
#     fig, axs = plt.subplots(5,2,figsize=(12,25))
#     for i in range(0,10):
#         plot = data_product[data_product['cluster']==i]
#         plot = plot['Product'].value_counts().to_frame().reset_index()
#         bars = axs[row[i]][col[i]].barh(plot[plot.columns[0]], plot[plot.columns[1]])
#         axs[row[i]][col[i]].bar_label(bars, padding=2)
#         axs[row[i]][col[i]].margins(x=0.15, y=0.01)
#         axs[row[i]][col[i]].set_title('Iteration '+str(r)+' Cluster '+str(i)+' - '+
#                                       str(clusterCount.iloc[i,0])+' Contracts')
#     fig.tight_layout(pad=2)
#     plt.show()
#     fig = plt.figure()
#     fig, axs = plt.subplots(5,2,figsize=(12,25))
#     for i in range(0,10):
#         plot = data_product[data_product['cluster']==temp[i]]
#         plot = plot['Product'].value_counts().to_frame().reset_index()
#         bars = axs[row[i]][col[i]].barh(plot[plot.columns[0]], plot[plot.columns[1]])
#         axs[row[i]][col[i]].bar_label(bars, padding=2)
#         axs[row[i]][col[i]].margins(x=0.15, y=0.01)
#         axs[row[i]][col[i]].set_title('Iteration '+str(r)+' Cluster '+str(temp[i])+' - '+
#                                       str(clusterCount.iloc[temp[i],0])+' Contracts')
#     fig.tight_layout(pad=2)
#     plt.show()
#     fig = plt.figure()
#     fig, axs = plt.subplots(5,2,figsize=(12,25))
#     for i in range(0,10):
#         plot = data_segment[data_segment['cluster']==i]
#         plot = plot['Segment'].value_counts().to_frame().reset_index()
#         bars = axs[row[i]][col[i]].barh(plot[plot.columns[0]], plot[plot.columns[1]])
#         axs[row[i]][col[i]].bar_label(bars, padding=2)
#         axs[row[i]][col[i]].margins(x=0.15, y=0.01)
#         axs[row[i]][col[i]].set_title('Iteration '+str(r)+' Cluster '+str(i)+' - '+
#                                       str(clusterCount.iloc[i,0])+' Contracts')
#     fig.tight_layout(pad=2)
#     plt.show()
#     fig = plt.figure()
#     fig, axs = plt.subplots(5,2,figsize=(12,25))
#     for i in range(0,10):
#         plot = data_segment[data_segment['cluster']==temp[i]]
#         plot = plot['Segment'].value_counts().to_frame().reset_index()
#         bars = axs[row[i]][col[i]].barh(plot[plot.columns[0]], plot[plot.columns[1]])
#         axs[row[i]][col[i]].bar_label(bars, padding=2)
#         axs[row[i]][col[i]].margins(x=0.15, y=0.01)
#         axs[row[i]][col[i]].set_title('Iteration '+str(r)+' Cluster '+str(temp[i])+' - '+
#                                       str(clusterCount.iloc[temp[i],0])+' Contracts')
#     fig.tight_layout(pad=2)
#     plt.show()
# # end 